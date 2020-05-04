package test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
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
