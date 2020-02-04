package test

import (
	"fmt"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
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
}
