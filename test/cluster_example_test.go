package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestTerraformAwsEksExample(t *testing.T) {
	t.Parallel()

	workingDir := "../examples/cluster"

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployTerraform(t, workingDir)
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateCluster(t, workingDir)
	})
}

func deployTerraform(t *testing.T, workingDir string) {
	uniqueId := random.UniqueId()
	clusterName := fmt.Sprintf("testing-%s", uniqueId)

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: workingDir,
		Vars: map[string]interface{}{
			"cluster_name": clusterName,
		},
	}

	// Save the Terraform Options struct, so future test stages can use it
	test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)

	// Run `terraform init` and `terraform apply`. Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)
}

func validateCluster(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	kubeconfig, err := writeKubeconfig(terraform.Output(t, terraformOptions, "kubeconfig"))
	if err != nil {
		t.Error("Error writing kubeconfig file:", err)
	}
	defer os.Remove(kubeconfig)

	k8sOptions := k8s.NewKubectlOptions("", kubeconfig, "default")

	// Do a thing with the API to check it works
	k8s.GetServiceAccount(t, k8sOptions, "default")

}

func cleanupTerraform(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	terraform.Destroy(t, terraformOptions)
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
