package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"io/ioutil"
	"os"
	"testing"
)

func TestTerraformAwsHelloWorldExample(t *testing.T) {
	t.Parallel()

	uniqueId := random.UniqueId()
	clusterName := fmt.Sprintf("testing-%s", uniqueId)

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: "../examples/cluster",
		Vars: map[string]interface{}{
			"cluster_name": clusterName,
		},
	}

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer terraform.Destroy(t, terraformOptions)

	// Run `terraform init` and `terraform apply`. Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)

	// Write the kubeconfig file
	kubeconfig, err := writeKubeconfig(terraform.Output(t, terraformOptions, "kubeconfig"))
	if err != nil {
		t.Error("Error writing kubeconfig file:", err)
	}
	defer os.Remove(kubeconfig)

	k8sOptions := k8s.NewKubectlOptions("", kubeconfig, "default")

	// Do a thing with the API to check it works
	k8s.GetServiceAccount(t, k8sOptions, "default")
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
