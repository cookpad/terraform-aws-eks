package test

import (
	"fmt"
	"testing"

	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestTerraformAwsEksVPC(t *testing.T) {
	t.Parallel()
	workingDir := "../examples/vpc"
	awsRegion := "us-east-1"

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployTerraform(t, workingDir, map[string]interface{}{})
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
	})

	test_structure.RunTestStage(t, "validate_vpc", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		vpcId := terraform.Output(t, terraformOptions, "vpc_id")
		subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)
		require.Equal(t, 6, len(subnets))

		for _, subnetId := range terraform.OutputList(t, terraformOptions, "public_subnet_ids") {
			assert.True(t, aws.IsPublicSubnet(t, subnetId, awsRegion))
		}

		for _, subnetId := range terraform.OutputList(t, terraformOptions, "private_subnet_ids") {
			assert.False(t, aws.IsPublicSubnet(t, subnetId, awsRegion))
		}

		// Create a security group not managed by terraform (like eks does) to check that cleanup is successful
		sgName := fmt.Sprintf("terraform-aws-eks-vpc-testing-sg-%s", random.UniqueId())
		sgInput := ec2.CreateSecurityGroupInput{
			GroupName:   &sgName,
			Description: &sgName,
			VpcId:       &vpcId,
		}
		aws.NewEc2Client(t, awsRegion).CreateSecurityGroup(&sgInput)
	})
}
