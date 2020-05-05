package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
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

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
		cleanupTerraform(t, environmentDir)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		uniqueId := random.UniqueId()
		clusterName := fmt.Sprintf("terraform-aws-eks-testing-%s", uniqueId)
		vpcCidr := aws.GetRandomPrivateCidrBlock(18)
		deployTerraform(t, environmentDir, map[string]interface{}{
			"cluster_name": clusterName,
			"cidr_block":   vpcCidr,
		})
		deployTerraform(t, workingDir, map[string]interface{}{
			"cluster_name": clusterName,
		})
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		validateCluster(t, kubeconfig)
		validateSecretsBehaviour(t, kubeconfig)
		validateMetricsServer(t, kubeconfig)
		validateClusterAutoscaler(t, kubeconfig)
		validateNodeLabels(t, kubeconfig, terraform.Output(t, terraformOptions, "cluster_name"))
		validateNodeTerminationHandler(t, kubeconfig)
		validateNodeExporter(t, kubeconfig)
		validateGPUNodes(t, kubeconfig)
		admin_kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"), terraform.Output(t, terraformOptions, "test_role_arn"))
		defer os.Remove(admin_kubeconfig)
		validateAdminRole(t, admin_kubeconfig)
	})
}

func validateGPUNodes(t *testing.T, kubeconfig string) {
	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_GPU_WORKLOAD, namespace, namespace)
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, workload)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)

	filters := metav1.ListOptions{
		LabelSelector: "app=gpu-test-workload",
	}
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 1, 1, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		WaitUntilPodSucceeded(t, kubectlOptions, pod.Name, 24, 10*time.Second)
	}
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

// WaitUntilPodSucceeded waits until the pod has reached the Succeeded status, retrying the check for the specified amount of times, sleeping
// for the provided duration between each try. This will fail the test if there is an error or if the check times out.
func WaitUntilPodSucceeded(t *testing.T, options *k8s.KubectlOptions, podName string, retries int, sleepBetweenRetries time.Duration) {
	require.NoError(t, WaitUntilPodSucceededE(t, options, podName, retries, sleepBetweenRetries))
}

// WaitUntilPodCompletedE waits until the pod has reached the Succeeded status, retrying the check for the specified amount of times, sleeping
// for the provided duration between each try.
func WaitUntilPodSucceededE(t *testing.T, options *k8s.KubectlOptions, podName string, retries int, sleepBetweenRetries time.Duration) error {
	statusMsg := fmt.Sprintf("Wait for pod %s to Succeed.", podName)
	message, err := retry.DoWithRetryE(
		t,
		statusMsg,
		retries,
		sleepBetweenRetries,
		func() (string, error) {
			pod, err := k8s.GetPodE(t, options, podName)
			if err != nil {
				return "", err
			}
			if pod.Status.Phase != corev1.PodSucceeded {
				return "", k8s.NewPodNotAvailableError(pod)
			}
			return "Pod is now Succeeded", nil
		},
	)
	if err != nil {
		logger.Logf(t, "Timedout waiting for Pod to Succeed: %s", err)
		return err
	}
	logger.Logf(t, message)
	return nil
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
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-role.kubernetes.io/critical-addons=true"})
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
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, secretManifest)
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

func validateMetricsServer(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	maxRetries := 20
	sleepBetweenRetries := 6 * time.Second
	retry.DoWithRetry(t, "wait for kubectl top pods to work", maxRetries, sleepBetweenRetries, func() (string, error) {
		return k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "top", "pods")
	})
}

func validateClusterAutoscaler(t *testing.T, kubeconfig string) {
	filters := metav1.ListOptions{
		LabelSelector: "app.kubernetes.io/name=aws-cluster-autoscaler",
	}

	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")

	// Check that the autoscaler pods are running
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 1, 1, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}

	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions = k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_WORKLOAD, namespace, namespace)
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, workload)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)

	// Check the cluster scales up
	waitForNodes(t, kubectlOptions, 6)

	// Check that the example workload pods can all run
	filters = metav1.ListOptions{
		LabelSelector: "app=test-workload",
	}
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 6, 1, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 12, 10*time.Second)
	}
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
  replicas: 6
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
	filters := metav1.ListOptions{
		LabelSelector: "k8s-app=aws-node-termination-handler",
	}

	// Check that the handler is running on all the nodes
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, len(nodes), 6, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}
}

func validateNodeExporter(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	nodes := k8s.GetNodes(t, kubectlOptions)
	filters := metav1.ListOptions{
		LabelSelector: "app=prometheus-node-exporter",
	}

	// Check that the exporter is running on all the nodes
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, len(nodes), 6, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}
}

func writeKubeconfig(t *testing.T, opts ...string) string {
	file, err := ioutil.TempFile(os.TempDir(), "kubeconfig-")
	require.NoError(t, err)
	args := []string{
		"eks",
		"update-kubeconfig",
		"--name", opts[0],
		"--kubeconfig", file.Name(),
		"--region", "us-east-1",
	}
	if len(opts) > 1 {
		args = append(args, "--role-arn", opts[1])
	}
	shell.RunCommand(t, shell.Command{
		Command: "aws",
		Args:    args,
	})
	return file.Name()
}

func waitForCluster(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	maxRetries := 40
	sleepBetweenRetries := 10 * time.Second
	retry.DoWithRetry(t, "Check that access to the k8s api works", maxRetries, sleepBetweenRetries, func() (string, error) {
		// Try an operation on the API to check it works
		_, err := k8s.GetServiceAccountE(t, kubectlOptions, "default")
		return "", err
	})

}

func waitForNodes(t *testing.T, kubectlOptions *k8s.KubectlOptions, numNodes int) {
	maxRetries := 40
	sleepBetweenRetries := 10 * time.Second
	retry.DoWithRetry(t, "wait for nodes to launch", maxRetries, sleepBetweenRetries, func() (string, error) {
		nodes, err := k8s.GetNodesE(t, kubectlOptions)

		if err != nil {
			return "", err
		}

		// Wait for at least n nodes to start
		if len(nodes) < numNodes {
			return "", fmt.Errorf("less than %d nodes started", numNodes)
		}

		return "", err
	})

	// Wait for the nodes to be ready
	k8s.WaitUntilAllNodesReady(t, kubectlOptions, maxRetries, sleepBetweenRetries)
}
