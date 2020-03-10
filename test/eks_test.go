package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestTerraformAwsEksRoot(t *testing.T) {
	t.Parallel()

	workingDir := "../examples/eks"

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

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)

		validateCluster(t, kubeconfig)
		validateSecretsBehaviour(t, kubeconfig)
		validateMetricsServer(t, kubeconfig)
		validateClusterAutoscaler(t, kubeconfig)
		validateNodeTerminationHandler(t, kubeconfig)
		validateNodeExporter(t, kubeconfig)
	})
}
