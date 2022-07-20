package test

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	authv1 "k8s.io/api/authorization/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestTerraformAwsEksCluster(t *testing.T) {
	t.Parallel()

	environmentDir := "../examples/cluster/environment"
	workingDir := "../examples/cluster"
	awsRegion := "us-east-1"

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
	})

	test_structure.RunTestStage(t, "deploy_cluster", func() {
		uniqueId := random.UniqueId()
		clusterName := fmt.Sprintf("terraform-aws-eks-testing-%s", uniqueId)
		deployTerraform(t, environmentDir, map[string]interface{}{})
		deployTerraform(t, workingDir, map[string]interface{}{
			"cluster_name":       clusterName,
			"aws_ebs_csi_driver": false,
		})
	})

	test_structure.RunTestStage(t, "validate_vpc", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, environmentDir)
		vpcId := terraform.Output(t, terraformOptions, "vpc_id")
		subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)
		require.Equal(t, 6, len(subnets))

		for _, subnetId := range terraform.OutputList(t, terraformOptions, "public_subnet_ids") {
			assert.True(t, aws.IsPublicSubnet(t, subnetId, awsRegion))
		}

		for _, subnetId := range terraform.OutputList(t, terraformOptions, "private_subnet_ids") {
			assert.False(t, aws.IsPublicSubnet(t, subnetId, awsRegion))
		}
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		validateCluster(t, kubeconfig)
		validateSecretsBehaviour(t, kubeconfig)
		validateDNS(t, kubeconfig)
		validateNodeLabels(t, kubeconfig, terraform.Output(t, terraformOptions, "cluster_name"))
		admin_kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"), terraform.Output(t, terraformOptions, "test_role_arn"))
		defer os.Remove(admin_kubeconfig)
		validateAdminRole(t, admin_kubeconfig)
	})

	test_structure.RunTestStage(t, "validate_standard_node_group", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		nodeGroupDir := "../examples/cluster/standard_node_group"
		deployTerraform(t, nodeGroupDir, map[string]interface{}{})
		defer cleanupTerraform(t, nodeGroupDir)
		validateClusterAutoscaler(t, kubeconfig)
		validateKubeBench(t, kubeconfig)
		validateStorage(t, kubeconfig)
		overideAndApplyTerraform(t, workingDir, map[string]interface{}{
			"aws_ebs_csi_driver": true,
		})
		validateStorage(t, kubeconfig)
	})

	test_structure.RunTestStage(t, "validate_bottlerocket_node_group", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		nodeGroupDir := "../examples/cluster/bottlerocket_node_group"
		overideAndApplyTerraform(t, workingDir, map[string]interface{}{
			"aws_ebs_csi_driver": true,
		})
		deployTerraform(t, nodeGroupDir, map[string]interface{}{})
		defer cleanupTerraform(t, nodeGroupDir)
		validateClusterAutoscaler(t, kubeconfig)
		// https://github.com/bottlerocket-os/bottlerocket/pull/1295
		validateKubeBenchExpectedFails(t, kubeconfig, 0)
		validateStorage(t, kubeconfig)
	})

	test_structure.RunTestStage(t, "validate_bottlerocket_gpu_node_group", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		gpuNodeGroupDir := "../examples/cluster/bottlerocket_gpu_node_group"
		deployTerraform(t, gpuNodeGroupDir, map[string]interface{}{})
		defer cleanupTerraform(t, gpuNodeGroupDir)
		validateGPUNodes(t, kubeconfig)
		validateKubeBench(t, kubeconfig)
	})
}

func validateNodeLabels(t *testing.T, kubeconfig string, clusterName string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-group.k8s.cookpad.com/name=standard-nodes"})
	require.NoError(t, err)
	for _, node := range nodes {
		assert.Equal(t, clusterName, node.Labels["cookpad.com/terraform-aws-eks-test-environment"])
	}
}

func validateAdminRole(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	k8s.CanIDo(t, kubectlOptions, authv1.ResourceAttributes{
		Namespace: "*",
		Verb:      "*",
		Group:     "*",
		Version:   "*",
	})
}

func validateCluster(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	waitForCluster(t, kubectlOptions)
	waitForNodes(t, kubectlOptions, 2)
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-group.k8s.cookpad.com/name=critical-addons"})
	require.NoError(t, err)
	assert.GreaterOrEqual(t, len(nodes), 2)
	for _, node := range nodes {
		taint := node.Spec.Taints[0]
		assert.Equal(t, "CriticalAddonsOnly", taint.Key)
		assert.Equal(t, "true", taint.Value)
		assert.Equal(t, corev1.TaintEffectNoSchedule, taint.Effect)
	}
}

func validateSecretsBehaviour(t *testing.T, kubeconfig string) {
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, namespace)
	secretManifest := fmt.Sprintf(EXAMPLE_SECRET, namespace, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)
	k8s.KubectlApplyFromString(t, kubectlOptions, secretManifest)
	secret := k8s.GetSecret(t, kubectlOptions, "keys-to-the-kingdom")
	password := secret.Data["password"]
	assert.Equal(t, "Open Sesame", string(password))
}

const EXAMPLE_SECRET = `---
apiVersion: v1
kind: Namespace
metadata:
  name: %s
---
apiVersion: v1
kind: Secret
metadata:
  name: keys-to-the-kingdom
  namespace: %s
type: Opaque
data:
  password: T3BlbiBTZXNhbWU=
`

func validateDNS(t *testing.T, kubeconfig string) {
	nameSuffix := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	test := fmt.Sprintf(DNS_TEST_JOB, nameSuffix)
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, test)
	k8s.KubectlApplyFromString(t, kubectlOptions, test)
	WaitUntilPodsSucceeded(t, kubectlOptions, metav1.ListOptions{LabelSelector: "job-name=nslookup-" + nameSuffix}, 1, 30, 10*time.Second)
}

const DNS_TEST_JOB = `---
apiVersion: batch/v1
kind: Job
metadata:
  name: nslookup-%s
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: dnsutils
        image: gcr.io/kubernetes-e2e-test-images/dnsutils:1.3
        command:
          - nslookup
          - kubernetes.default
        imagePullPolicy: IfNotPresent
      restartPolicy: Never
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
  backoffLimit: 4
`

func validateClusterAutoscaler(t *testing.T, kubeconfig string) {

	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")

	// Check that the autoscaler pods are running
	WaitUntilPodsAvailable(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app.kubernetes.io/name=aws-cluster-autoscaler"}, 1, 30, 6*time.Second)

	nodes, err := k8s.GetNodesE(t, kubectlOptions)
	if err != nil {
		t.Fatal("Couldn't get node count")
	}

	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions = k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_WORKLOAD, namespace, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)

	// Check the cluster scales up
	waitForNodes(t, kubectlOptions, len(nodes)+1)

	// Check that the example workload pods can all run
	WaitUntilPodsAvailable(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app=test-workload"}, 2, 50, 32*time.Second)
}

const EXAMPLE_WORKLOAD = `---
apiVersion: v1
kind: Namespace
metadata:
  name: %s
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-workload-deployment
  namespace: %s
  labels:
    app: test-workload
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-workload
  template:
    metadata:
      labels:
        app: test-workload
    spec:
      containers:
      - name: workload
        image: 602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/pause-amd64:3.1
        resources:
          requests:
            cpu: "1100m"
`

func validateGPUNodes(t *testing.T, kubeconfig string) {
	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_GPU_WORKLOAD, namespace, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)
	WaitUntilPodsSucceeded(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app=gpu-test-workload"}, 1, 30, 32*time.Second)
}

const EXAMPLE_GPU_WORKLOAD = `---
apiVersion: v1
kind: Namespace
metadata:
  name: %s
---
apiVersion: batch/v1
kind: Job
metadata:
  name: test-gpu-workload
  namespace: %s
spec:
  template:
    metadata:
      labels:
        app: gpu-test-workload
    spec:
      restartPolicy: OnFailure
      containers:
      - name: nvidia-smi
        image: nvidia/cuda:9.2-devel
        args:
        - "nvidia-smi"
        - "--list-gpus"
        resources:
          limits:
            nvidia.com/gpu: 1
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
`

func validateStorage(t *testing.T, kubeconfig string) {
	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_STORAGE_WORKLOAD, namespace, namespace, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)
	WaitUntilPodsSucceeded(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app=storage-test-workload"}, 1, 30, 10*time.Second)
}

const EXAMPLE_STORAGE_WORKLOAD = `---
apiVersion: v1
kind: Namespace
metadata:
  name: %s
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-claim
  namespace: %s
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: test-storage-workload
  namespace: %s
spec:
  template:
    metadata:
      labels:
        app: storage-test-workload
    spec:
      restartPolicy: OnFailure
      containers:
      - name: app
        image: alpine
        command: ["/bin/sh"]
        args: ["-c", "echo $(date -u) >> /data/out.txt && cat /data/out.txt"]
        volumeMounts:
        - name: persistent-storage
          mountPath: /data
      volumes:
      - name: persistent-storage
        persistentVolumeClaim:
          claimName: ebs-claim
`

func validateKubeBench(t *testing.T, kubeconfig string) {
	validateKubeBenchExpectedFails(t, kubeconfig, 0)
}

func validateKubeBenchExpectedFails(t *testing.T, kubeconfig string, expectedFails int) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-bench")
	defer k8s.DeleteNamespace(t, kubectlOptions, "kube-bench")
	k8s.KubectlApplyFromString(t, kubectlOptions, KUBEBENCH_MANIFEST)
	WaitUntilPodsSucceeded(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app=kube-bench"}, 1, 30, 5*time.Second)
	output, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "logs", "-l", "app=kube-bench")
	require.NoError(t, err)
	resultWrapper := KubeBenchResult{}
	err = json.Unmarshal([]byte(output), &resultWrapper)
	require.NoError(t, err)
	result := resultWrapper.Totals
	if !assert.Equal(t, expectedFails, result.TotalFail) {
		fmt.Printf(`unexpected total_fail: %s`, output)
	}
	// https://github.com/awslabs/amazon-eks-ami/pull/391
	if !assert.LessOrEqual(t, result.TotalWarn, 1) {
		fmt.Printf(`>=1 total_warn: %s`, output)
	}
}

type KubeBenchResult struct {
	Totals KubeBenchResultTotals `json:"Totals"`
}

type KubeBenchResultTotals struct {
	TotalPass int `json:"total_pass"`
	TotalFail int `json:"total_fail"`
	TotalWarn int `json:"total_warn"`
	TotalInfo int `json:"total_info"`
}

const KUBEBENCH_MANIFEST = `---
apiVersion: v1
kind: Namespace
metadata:
  name: kube-bench
---
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
  namespace: kube-bench
spec:
  template:
    metadata:
      labels:
        app: kube-bench
    spec:
      hostPID: true
      containers:
        - name: kube-bench
          image: aquasec/kube-bench:v0.6.8
          command: ["kube-bench", "run", "--targets=node", "--benchmark", "eks-1.0.1", "--json"]
          volumeMounts:
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: etc-systemd
              mountPath: /etc/systemd
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
      restartPolicy: Never
      volumes:
        - name: var-lib-kubelet
          hostPath:
            path: "/var/lib/kubelet"
        - name: etc-systemd
          hostPath:
            path: "/etc/systemd"
        - name: etc-kubernetes
          hostPath:
            path: "/etc/kubernetes"
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
`
