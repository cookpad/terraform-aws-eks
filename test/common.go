package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/stretchr/testify/require"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func deployTerraform(t *testing.T, workingDir string, vars map[string]interface{}) {
	var terraformOptions *terraform.Options

	if test_structure.IsTestDataPresent(t, test_structure.FormatTestDataPath(workingDir, "TerraformOptions.json")) {
		terraformOptions = test_structure.LoadTerraformOptions(t, workingDir)
		for k, v := range vars {
			if _, ok := terraformOptions.Vars[k]; !ok {
				terraformOptions.Vars[k] = v
			}
		}
	} else {
		terraformOptions = &terraform.Options{
			// The path to where our Terraform code is located
			TerraformDir: workingDir,
			Vars:         vars,
		}

		// Save the Terraform Options struct, so future test stages can use it
		test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
	}

	// Run `terraform init` and `terraform apply`. Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)
}

func overideAndApplyTerraform(t *testing.T, workingDir string, vars map[string]interface{}) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	for k, v := range vars {
		terraformOptions.Vars[k] = v
	}
	terraform.InitAndApply(t, terraformOptions)
}

func cleanupTerraform(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	terraform.Destroy(t, terraformOptions)
	test_structure.CleanupTestDataFolder(t, workingDir)
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

func WaitUntilPodsAvailableE(t *testing.T, options *k8s.KubectlOptions, filters metav1.ListOptions, desiredCount, retries int, sleepBetweenRetries time.Duration) error {
	statusMsg := fmt.Sprintf("Wait for num pods available to match desired count %d.", desiredCount)
	message, err := retry.DoWithRetryE(
		t,
		statusMsg,
		retries,
		sleepBetweenRetries,
		func() (string, error) {
			pods, err := k8s.ListPodsE(t, options, filters)
			if err != nil {
				return "", err
			}
			if len(pods) != desiredCount {
				return "", k8s.DesiredNumberOfPodsNotCreated{Filter: filters, DesiredCount: desiredCount}
			}
			for _, pod := range pods {
				pod, err := k8s.GetPodE(t, options, pod.Name)
				if err != nil {
					return "", err
				}
				if !k8s.IsPodAvailable(pod) {
					return "", k8s.NewPodNotAvailableError(pod)
				}
			}
			return "Pods are now available", nil
		},
	)
	if err != nil {
		logger.Logf(t, "Timedout waiting for the desired number of Pods to be available: %s", err)
		return err
	}
	logger.Logf(t, message)
	return nil
}

func WaitUntilPodsAvailable(t *testing.T, options *k8s.KubectlOptions, filters metav1.ListOptions, desiredCount, retries int, sleepBetweenRetries time.Duration) {
	require.NoError(t, WaitUntilPodsAvailableE(t, options, filters, desiredCount, retries, sleepBetweenRetries))
}

func WaitUntilPodsSucceededE(t *testing.T, options *k8s.KubectlOptions, filters metav1.ListOptions, desiredCount, retries int, sleepBetweenRetries time.Duration) error {
	statusMsg := "Wait for pods to Succeed."
	message, err := retry.DoWithRetryE(
		t,
		statusMsg,
		retries,
		sleepBetweenRetries,
		func() (string, error) {
			pods, err := k8s.ListPodsE(t, options, filters)
			if err != nil {
				return "", err
			}
			if len(pods) != desiredCount {
				return "", k8s.DesiredNumberOfPodsNotCreated{Filter: filters, DesiredCount: desiredCount}
			}
			for _, pod := range pods {
				pod, err := k8s.GetPodE(t, options, pod.Name)
				if err != nil {
					return "", err
				}
				if pod.Status.Phase != corev1.PodSucceeded {
					return "", k8s.NewPodNotAvailableError(pod)
				}
			}
			return "Pods have now Succeeded", nil
		},
	)
	if err != nil {
		logger.Logf(t, "Timedout waiting for the desired number of Pods to Succeed: %s", err)
		return err
	}
	logger.Logf(t, message)
	return nil
}

func WaitUntilPodsSucceeded(t *testing.T, options *k8s.KubectlOptions, filters metav1.ListOptions, desiredCount, retries int, sleepBetweenRetries time.Duration) {
	require.NoError(t, WaitUntilPodsSucceededE(t, options, filters, desiredCount, retries, sleepBetweenRetries))
}
