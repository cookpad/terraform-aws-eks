package test

import (
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
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

func removeSecurityGroups(t *testing.T, workingDir string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	client := ec2.New(session.New(&aws.Config{Region: aws.String("us-east-1")}))
	securityGroups(t, client, vpcId, func(sg *ec2.SecurityGroup) {
		revokeRules(t, client, sg)
	})
	securityGroups(t, client, vpcId, func(sg *ec2.SecurityGroup) {
		deleteSecurityGroup(t, client, sg)
	})

}

func securityGroups(t *testing.T, client *ec2.EC2, vpcId string, function func(*ec2.SecurityGroup)) {
	input := &ec2.DescribeSecurityGroupsInput{
		Filters: []*ec2.Filter{
			{
				Name: aws.String("vpc-id"),
				Values: []*string{
					aws.String(vpcId),
				},
			},
		},
	}
	err := client.DescribeSecurityGroupsPages(
		input,
		func(page *ec2.DescribeSecurityGroupsOutput, lastPage bool) bool {
			for _, sg := range page.SecurityGroups {
				function(sg)
			}
			return !lastPage
		},
	)
	if err != nil {
		logger.Log(t, err.Error())
	}
}

func deleteSecurityGroup(t *testing.T, client *ec2.EC2, sg *ec2.SecurityGroup) {
	if *sg.GroupName == "default" {
		return
	}
	logger.Log(t, "Deleting security group:", *sg.GroupName, *sg.GroupId)
	deleteInput := &ec2.DeleteSecurityGroupInput{
		GroupId: aws.String(*sg.GroupId),
	}
	_, err := client.DeleteSecurityGroup(deleteInput)
	if err != nil {
		logger.Log(t, err.Error())
	}
}

func revokeRules(t *testing.T, client *ec2.EC2, sg *ec2.SecurityGroup) {
	for _, permission := range sg.IpPermissions {
		input := &ec2.RevokeSecurityGroupIngressInput{
			GroupId:       aws.String(*sg.GroupId),
			IpPermissions: []*ec2.IpPermission{permission},
		}
		_, err := client.RevokeSecurityGroupIngress(input)
		if err != nil {
			logger.Log(t, err.Error())
		}
	}
}
