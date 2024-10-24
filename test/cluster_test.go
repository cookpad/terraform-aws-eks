package test

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	authv1 "k8s.io/api/authorization/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestTerraformAwsEksCluster(t *testing.T) {
	t.Parallel()

	environmentDir := "../examples/cluster/environment"
	workingDir := "../examples/cluster"

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
	})

	test_structure.RunTestStage(t, "deploy_cluster", func() {
		uniqueId := random.UniqueId()
		clusterName := fmt.Sprintf("terraform-aws-eks-testing-%s", uniqueId)
		deployTerraform(t, environmentDir, map[string]interface{}{})
		deployTerraform(t, workingDir, map[string]interface{}{
			"cluster_name": clusterName,
		})
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		clusterName = terraform.Output(t, terraformOptions, "cluster_name")
		kubeconfig := writeKubeconfig(t, clusterName)
		defer os.Remove(kubeconfig)
		kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
		waitForCluster(t, kubectlOptions)
	})

	test_structure.RunTestStage(t, "install_karpenter", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		clusterName := terraform.Output(t, terraformOptions, "cluster_name")
		sgName := terraform.Output(t, terraformOptions, "node_security_group_name")
		kubeconfig := writeKubeconfig(t, clusterName)
		defer os.Remove(kubeconfig)
		installKarpenter(t, kubeconfig, clusterName, sgName)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		validateSecretsBehaviour(t, kubeconfig)
		validateDNS(t, kubeconfig)
		admin_kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"), terraform.Output(t, terraformOptions, "test_role_arn"))
		defer os.Remove(admin_kubeconfig)
		validateAdminRole(t, admin_kubeconfig)
		validateKubeBench(t, kubeconfig)
		validateStorage(t, kubeconfig)
	})
}

func installKarpenter(t *testing.T, kubeconfig, clusterName, sgName string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "karpenter")
	helmOptions := helm.Options{
		KubectlOptions: kubectlOptions,
		ExtraArgs: map[string][]string{
			"upgrade": []string{"--create-namespace", "--version", "1.0.5", "--force"},
		},
	}
	helm.Upgrade(t, &helmOptions, "oci://public.ecr.aws/karpenter/karpenter-crd", "karpenter-crd")
	helmOptions = helm.Options{
		SetValues: map[string]string{
			"serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn": "arn:aws:iam::214219211678:role/Karpenter-" + clusterName,
			"settings.clusterName":                 clusterName,
			"settings.interruptionQueueName":       "Karpenter-" + clusterName,
			"controller.resources.requests.cpu":    "1",
			"controller.resources.requests.memory": "1Gi",
			"controller.resources.limits.cpu":      "1",
			"controller.resources.limits.memory":   "1Gi",
		},
		KubectlOptions: kubectlOptions,
		ExtraArgs: map[string][]string{
			"upgrade": []string{"--create-namespace", "--version", "1.0.5"},
		},
	}
	helm.Upgrade(t, &helmOptions, "oci://public.ecr.aws/karpenter/karpenter", "karpenter")
	WaitUntilPodsAvailable(t, kubectlOptions, metav1.ListOptions{LabelSelector: "app.kubernetes.io/name=karpenter"}, 2, 30, 6*time.Second)
	provisionerManifest := fmt.Sprintf(KARPENTER_PROVISIONER, sgName, clusterName)
	k8s.KubectlApplyFromString(t, kubectlOptions, provisionerManifest)
}

const KARPENTER_PROVISIONER = `---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      requirements:
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: [t3]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: [small, medium, large]
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiSelectorTerms:
    - alias: bottlerocket@latest
  subnetSelectorTerms:
    - tags:
        Name: terraform-aws-eks-test-environment-private*
  securityGroupSelectorTerms:
    - tags:
        Name: %s
  instanceProfile:
    KarpenterNode-%s
`

func validateAdminRole(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	k8s.CanIDo(t, kubectlOptions, authv1.ResourceAttributes{
		Namespace: "*",
		Verb:      "*",
		Group:     "*",
		Version:   "*",
	})
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
  storageClassName: gp2
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
	if !assert.Equal(t, result.TotalFail, 0) {
		fmt.Printf(`unexpected total_fail: %d`, result.TotalFail)
	}
	if !assert.Equal(t, result.TotalWarn, 0) {
		fmt.Printf(`unexpected total_warn: %d`, result.TotalWarn)
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

//Skipped tests:
//3.2.8: --hostname-override is used by bottlerocket to have hostname match the dns name of the ec2 instance, this is appropriate and not a security issue
//3.2.9: eventRecordQPS is 50 by default, and can be overidden as required by users
//3.2.11: See https://github.com/bottlerocket-os/bottlerocket/issues/3506 - the test checks for the presence of RotateKubeletServerCertificate feature gate, but this is set by default since k8s 1.12 so is not needed
//3.3.1: Manual test: bottlerocket is a container-optimized OS so we pass this control

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
          image: aquasec/kube-bench:v0.8.0
          command: ["kube-bench", "run", "--targets=node", "--benchmark", "eks-1.2.0", "--json", "--skip", "3.2.8,3.2.9,3.2.11,3.3.1"]
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
