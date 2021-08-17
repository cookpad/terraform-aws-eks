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
	"github.com/gruntwork-io/terratest/modules/retry"
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
		validateMetricsServer(t, kubeconfig)
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
		validateNodeTerminationHandler(t, kubeconfig)
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
		validateNodeTerminationHandler(t, kubeconfig)
		validateStorage(t, kubeconfig)
	})

	test_structure.RunTestStage(t, "validate_gpu_node_group", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		gpuNodeGroupDir := "../examples/cluster/gpu_node_group"
		deployTerraform(t, gpuNodeGroupDir, map[string]interface{}{})
		defer cleanupTerraform(t, gpuNodeGroupDir)
		validateGPUNodes(t, kubeconfig)
		validateKubeBench(t, kubeconfig)
		validateNodeTerminationHandler(t, kubeconfig)
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

func validateMetricsServer(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	maxRetries := 20
	sleepBetweenRetries := 6 * time.Second
	retry.DoWithRetry(t, "wait for kubectl top pods to work", maxRetries, sleepBetweenRetries, func() (string, error) {
		return k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "top", "pods")
	})
}

func validateClusterAutoscaler(t *testing.T, kubeconfig string) {

	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")

	// Check that the autoscaler pods are running
	WaitUntilPodsAvailable(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app.kubernetes.io/name=aws-cluster-autoscaler"}, 1, 30, 6*time.Second)

	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions = k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_WORKLOAD, namespace, namespace)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespace)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)

	// Check the cluster scales up
	waitForNodes(t, kubectlOptions, 2)

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

func validateNodeTerminationHandler(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	nodes := k8s.GetNodes(t, kubectlOptions)
	// Check that the handler is running on all the nodes
	WaitUntilPodsAvailable(t, kubectlOptions, metav1.ListOptions{LabelSelector: "k8s-app=aws-node-termination-handler"}, len(nodes), 30, 6*time.Second)
}

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

// Override kube-bench config.yaml for bottlerocket support
// This should be fixed with kube-bench 0.6.0
// https://github.com/aquasecurity/kube-bench/issues/808
const KUBEBENCH_MANIFEST = `---
apiVersion: v1
kind: Namespace
metadata:
  name: kube-bench
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-bench-config
  namespace: kube-bench
data:
  config.yaml: |
    ---
    ## Controls Files.
    # These are YAML files that hold all the details for running checks.
    #
    ## Uncomment to use different control file paths.
    # masterControls: ./cfg/master.yaml
    # nodeControls: ./cfg/node.yaml

    master:
      components:
        - apiserver
        - scheduler
        - controllermanager
        - etcd
        - flanneld
        # kubernetes is a component to cover the config file /etc/kubernetes/config that is referred to in the benchmark
        - kubernetes

      kubernetes:
        defaultconf: /etc/kubernetes/config

      apiserver:
        bins:
          - "kube-apiserver"
          - "hyperkube apiserver"
          - "hyperkube kube-apiserver"
          - "apiserver"
        confs:
          - /etc/kubernetes/manifests/kube-apiserver.yaml
          - /etc/kubernetes/manifests/kube-apiserver.yml
          - /etc/kubernetes/manifests/kube-apiserver.manifest
          - /var/snap/kube-apiserver/current/args
          - /var/snap/microk8s/current/args/kube-apiserver
        defaultconf: /etc/kubernetes/manifests/kube-apiserver.yaml

      scheduler:
        bins:
          - "kube-scheduler"
          - "hyperkube scheduler"
          - "hyperkube kube-scheduler"
          - "scheduler"
        confs:
          - /etc/kubernetes/manifests/kube-scheduler.yaml
          - /etc/kubernetes/manifests/kube-scheduler.yml
          - /etc/kubernetes/manifests/kube-scheduler.manifest
          - /var/snap/kube-scheduler/current/args
          - /var/snap/microk8s/current/args/kube-scheduler
        defaultconf: /etc/kubernetes/manifests/kube-scheduler.yaml
        kubeconfig:
          - /etc/kubernetes/scheduler.conf
        defaultkubeconfig: /etc/kubernetes/scheduler.conf

      controllermanager:
        bins:
          - "kube-controller-manager"
          - "kube-controller"
          - "hyperkube controller-manager"
          - "hyperkube kube-controller-manager"
          - "controller-manager"
        confs:
          - /etc/kubernetes/manifests/kube-controller-manager.yaml
          - /etc/kubernetes/manifests/kube-controller-manager.yml
          - /etc/kubernetes/manifests/kube-controller-manager.manifest
          - /var/snap/kube-controller-manager/current/args
          - /var/snap/microk8s/current/args/kube-controller-manager
        defaultconf: /etc/kubernetes/manifests/kube-controller-manager.yaml
        kubeconfig:
          - /etc/kubernetes/controller-manager.conf
        defaultkubeconfig: /etc/kubernetes/controller-manager.conf

      etcd:
        optional: true
        bins:
          - "etcd"
        confs:
          - /etc/kubernetes/manifests/etcd.yaml
          - /etc/kubernetes/manifests/etcd.yml
          - /etc/kubernetes/manifests/etcd.manifest
          - /etc/etcd/etcd.conf
          - /var/snap/etcd/common/etcd.conf.yml
          - /var/snap/etcd/common/etcd.conf.yaml
          - /var/snap/microk8s/current/args/etcd
          - /usr/lib/systemd/system/etcd.service
          - /etc/kubernetes/manifests
        defaultconf: /etc/kubernetes/manifests/etcd.yaml

      flanneld:
        optional: true
        bins:
          - flanneld
        defaultconf: /etc/sysconfig/flanneld

    node:
      components:
        - kubelet
        - proxy
        # kubernetes is a component to cover the config file /etc/kubernetes/config that is referred to in the benchmark
        - kubernetes

      kubernetes:
        defaultconf: "/etc/kubernetes/config"

      kubelet:
        cafile:
          - "/etc/kubernetes/pki/ca.crt"
          - "/etc/kubernetes/certs/ca.crt"
          - "/etc/kubernetes/cert/ca.pem"
          - "/var/snap/microk8s/current/certs/ca.crt"
        svc:
          # These paths must also be included
          #  in the 'confs' property below
          - "/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
          - "/etc/systemd/system/kubelet.service"
          - "/lib/systemd/system/kubelet.service"
          - "/etc/systemd/system/snap.kubelet.daemon.service"
          - "/etc/systemd/system/snap.microk8s.daemon-kubelet.service"
        bins:
          - "hyperkube kubelet"
          - "kubelet"
        kubeconfig:
          - "/etc/kubernetes/kubelet.conf"
          - "/var/lib/kubelet/kubeconfig"
          - "/etc/kubernetes/kubelet-kubeconfig"
          - "/etc/kubernetes/kubelet/kubeconfig"
          - "/var/snap/microk8s/current/credentials/kubelet.config"
        confs:
          - "/var/lib/kubelet/config.yaml"
          - "/var/lib/kubelet/config.yml"
          - "/etc/kubernetes/kubelet/kubelet-config.json"
          - "/etc/kubernetes/kubelet/config"
          - "/home/kubernetes/kubelet-config.yaml"
          - "/home/kubernetes/kubelet-config.yml"
          - "/etc/default/kubelet"
          - "/var/lib/kubelet/kubeconfig"
          - "/var/snap/kubelet/current/args"
          - "/var/snap/microk8s/current/args/kubelet"
          ## Due to the fact that the kubelet might be configured
          ## without a kubelet-config file, we use a work-around
          ## of pointing to the systemd service file (which can also
          ## hold kubelet configuration).
          ## Note: The following paths must match the one under 'svc'
          - "/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
          - "/etc/systemd/system/kubelet.service"
          - "/lib/systemd/system/kubelet.service"
          - "/etc/systemd/system/snap.kubelet.daemon.service"
          - "/etc/systemd/system/snap.microk8s.daemon-kubelet.service"
        defaultconf: "/var/lib/kubelet/config.yaml"
        defaultsvc: "/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
        defaultkubeconfig: "/etc/kubernetes/kubelet.conf"
        defaultcafile: "/etc/kubernetes/pki/ca.crt"

      proxy:
        optional: true
        bins:
          - "kube-proxy"
          - "hyperkube proxy"
          - "hyperkube kube-proxy"
          - "proxy"
        confs:
          - /etc/kubernetes/proxy
          - /etc/kubernetes/addons/kube-proxy-daemonset.yaml
          - /etc/kubernetes/addons/kube-proxy-daemonset.yml
          - /var/snap/kube-proxy/current/args
          - /var/snap/microk8s/current/args/kube-proxy
        kubeconfig:
          - "/etc/kubernetes/kubelet-kubeconfig"
          - "/etc/kubernetes/kubelet/config"
          - "/var/lib/kubelet/kubeconfig"
          - "/var/snap/microk8s/current/credentials/proxy.config"
        svc:
          - "/lib/systemd/system/kube-proxy.service"
          - "/etc/systemd/system/snap.microk8s.daemon-proxy.service"
        defaultconf: /etc/kubernetes/addons/kube-proxy-daemonset.yaml
        defaultkubeconfig: "/etc/kubernetes/proxy.conf"

    etcd:
      components:
        - etcd

      etcd:
        bins:
          - "etcd"
        confs:
          - /etc/kubernetes/manifests/etcd.yaml
          - /etc/kubernetes/manifests/etcd.yml
          - /etc/kubernetes/manifests/etcd.manifest
          - /etc/etcd/etcd.conf
          - /var/snap/etcd/common/etcd.conf.yml
          - /var/snap/etcd/common/etcd.conf.yaml
          - /var/snap/microk8s/current/args/etcd
          - /usr/lib/systemd/system/etcd.service
        defaultconf: /etc/kubernetes/manifests/etcd.yaml

    controlplane:
      components:
        - apiserver

      apiserver:
        bins:
          - "kube-apiserver"
          - "hyperkube apiserver"
          - "hyperkube kube-apiserver"
          - "apiserver"

    policies:
      components: []

    managedservices:
      components: []

    version_mapping:
      "1.15": "cis-1.5"
      "1.16": "cis-1.6"
      "1.17": "cis-1.6"
      "1.18": "cis-1.6"
      "1.19": "cis-1.6"
      "eks-1.0": "eks-1.0"
      "gke-1.0": "gke-1.0"
      "ocp-3.10": "rh-0.7"
      "ocp-3.11": "rh-0.7"
      "aks-1.0": "aks-1.0"

    target_mapping:
      "cis-1.5":
        - "master"
        - "node"
        - "controlplane"
        - "etcd"
        - "policies"
      "cis-1.6":
        - "master"
        - "node"
        - "controlplane"
        - "etcd"
        - "policies"
      "gke-1.0":
        - "master"
        - "node"
        - "controlplane"
        - "etcd"
        - "policies"
        - "managedservices"
      "eks-1.0":
        - "master"
        - "node"
        - "controlplane"
        - "policies"
        - "managedservices"
      "rh-0.7":
        - "master"
        - "node"
      "aks-1.0":
        - "master"
        - "node"
        - "controlplane"
        - "policies"
        - "managedservices"
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
          image: aquasec/kube-bench:0.5.0
          command: ["kube-bench", "node", "--benchmark", "eks-1.0", "--json"]
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
            - name: kube-bench-config
              mountPath: "/opt/kube-bench/cfg/config.yaml"
              subPath: "config.yaml"
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
        - name: kube-bench-config
          configMap:
            name: kube-bench-config
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
`
