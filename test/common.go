package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
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

func cleanupTerraform(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	terraform.Destroy(t, terraformOptions)
	test_structure.CleanupTestDataFolder(t, workingDir)
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
