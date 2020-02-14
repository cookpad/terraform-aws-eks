package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	k8s_core "k8s.io/api/core/v1"
)

func TestTerraformAwsEksCluster(t *testing.T) {
	t.Parallel()

	workingDir := "../examples/cluster"

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		uniqueId := random.UniqueId()
		clusterName := fmt.Sprintf("terraform-aws-eks-testing-%s", uniqueId)
		vpcCidr := aws.GetRandomPrivateCidrBlock(18)
		deployTerraform(t, workingDir, map[string]interface{}{
			"cluster_name": clusterName,
			"cidr_block":   vpcCidr,
		})
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateCluster(t, workingDir)
	})
}

func validateCluster(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	kubeconfig, err := writeKubeconfig(terraform.Output(t, terraformOptions, "kubeconfig"))
	if err != nil {
		t.Error("Error writing kubeconfig file:", err)
	}
	defer os.Remove(kubeconfig)

	k8sOptions := k8s.NewKubectlOptions("", kubeconfig, "default")

	maxRetries := 40
	sleepBetweenRetries := 10 * time.Second

	retry.DoWithRetry(t, "Check that access to the k8s api works", maxRetries, sleepBetweenRetries, func() (string, error) {
		// Try an operation on the API to check it works
		_, err := k8s.GetServiceAccountE(t, k8sOptions, "default")
		return "", err
	})

	retry.DoWithRetry(t, "wait for nodes to be up", maxRetries, sleepBetweenRetries, func() (string, error) {
		nodes, err := k8s.GetNodesE(t, k8sOptions)

		if err != nil {
			return "", err
		}

		// Wait for at least 3 nodes to start
		if len(nodes) < 3 {
			return "", fmt.Errorf("less than 3 nodes started")
		}

		// Wait for the nodes to be ready
		for _, node := range nodes {
			for _, condition := range node.Status.Conditions {
				if condition.Type == k8s_core.NodeReady {
					if condition.Status != k8s_core.ConditionTrue {
						return "", fmt.Errorf("A node: %s is not ready yet", node.Name)
					}
				}
			}
		}

		return "", err
	})

}

func writeKubeconfig(config string) (string, error) {
	file, err := ioutil.TempFile(os.TempDir(), "kubeconfig-")
	if err != nil {
		return "", err
	}
	if _, err = file.Write([]byte(config)); err != nil {
		return "", err
	}
	if err = file.Close(); err != nil {
		return "", err
	}

	return file.Name(), nil
}
