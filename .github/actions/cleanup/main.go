package main

import (
	"log"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/iam"
)

var (
	svc         = ec2.New(session.New())
	clusterName = ""
)

func main() {
	clusterName := os.Getenv("TERRAFORM_AWS_EKS_TEST_CLUSTER_NAME")
	if clusterName == "" {
		log.Fatal("cluster name not set")
	}

	DeleteIamRoles(clusterName)
	err := DeleteVpcByName(clusterName)
	if err != nil {
		log.Println(err)
	}
}

func DeleteIamRoles(clusterName string) {
	err := DeleteIamRole("eksServiceRole-" + clusterName)
	if err != nil {
		log.Println(err)
	}
	err = DeleteIamRole("EKSNode-" + clusterName)
	if err != nil {
		log.Println(err)
	}
}

func DeleteIamRole(name string) error {
	log.Println("deleting role: " + name)
	iamSvc := iam.New(session.New())
	result, err := iamSvc.ListAttachedRolePolicies(&iam.ListAttachedRolePoliciesInput{
		RoleName: aws.String(name),
	})
	if err != nil {
		return err
	}
	for _, policy := range result.AttachedPolicies {
		_, err := iamSvc.DetachRolePolicy(&iam.DetachRolePolicyInput{
			PolicyArn: policy.PolicyArn,
			RoleName:  aws.String(name),
		})
		if err != nil {
			return err
		}
	}
	rolePolicies, err := iamSvc.ListRolePolicies(&iam.ListRolePoliciesInput{
		RoleName: aws.String(name),
	})
	if err != nil {
		return err
	}
	for _, policyName := range rolePolicies.PolicyNames {
		_, err := iamSvc.DeleteRolePolicy(&iam.DeleteRolePolicyInput{
			PolicyName: policyName,
			RoleName:   aws.String(name),
		})
		if err != nil {
			return err
		}
	}
	_, err = iamSvc.RemoveRoleFromInstanceProfile(&iam.RemoveRoleFromInstanceProfileInput{
		InstanceProfileName: aws.String(name),
		RoleName:            aws.String(name),
	})
	instanceProfile := true
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			switch aerr.Code() {
			case iam.ErrCodeNoSuchEntityException:
				instanceProfile = false
			default:
				return err
			}
		} else {
			return err
		}
	}
	if instanceProfile {
		_, err := iamSvc.DeleteInstanceProfile(&iam.DeleteInstanceProfileInput{
			InstanceProfileName: aws.String(name),
		})
		if err != nil {
			return err
		}
	}
	_, err = iamSvc.DeleteRole(&iam.DeleteRoleInput{
		RoleName: aws.String(name),
	})
	return err
}

func DeleteVpcByName(clusterName string) error {
	var err error
	filters := []*ec2.Filter{
		&ec2.Filter{
			Name:   aws.String("tag:Name"),
			Values: []*string{aws.String(clusterName)},
		},
	}
	svc.DescribeVpcsPages(&ec2.DescribeVpcsInput{Filters: filters}, func(output *ec2.DescribeVpcsOutput, lastPage bool) bool {
		for _, vpc := range output.Vpcs {
			err = DeleteVpc(*vpc.VpcId)
			if err != nil {
				return false
			}
		}
		return true
	})

	return err
}

func DeleteVpc(id string) error {
	log.Println("preparing to delete: ", id)
	err := DeleteNatGateways(id)
	if err != nil {
		return err
	}

	err = DeleteInternetGateways(id)
	if err != nil {
		return err
	}

	err = DeleteSecurityGroups(id)
	if err != nil {
		return err
	}

	err = DeleteSubnets(id)
	if err != nil {
		return err
	}

	err = DeleteRouteTables(id)
	if err != nil {
		return err
	}

	log.Println("deleting: ", id)
	_, err = svc.DeleteVpc(&ec2.DeleteVpcInput{VpcId: aws.String(id)})
	if err != nil {
		return err
	}
	return nil
}

func DeleteNatGateways(vpcId string) error {
	var err error
	svc.DescribeNatGatewaysPages(
		&ec2.DescribeNatGatewaysInput{
			Filter: []*ec2.Filter{
				{
					Name: aws.String("vpc-id"),
					Values: []*string{
						aws.String(vpcId),
					},
				},
			},
		},
		func(result *ec2.DescribeNatGatewaysOutput, lastPage bool) bool {
			for _, gateway := range result.NatGateways {
				log.Println("deleting: ", *gateway.NatGatewayId)
				_, err = svc.DeleteNatGateway(&ec2.DeleteNatGatewayInput{
					NatGatewayId: gateway.NatGatewayId,
				})
				if err != nil {
					log.Println(err)
					return false
				}

			}
			return !lastPage
		},
	)
	if err != nil {
		return err
	}
	checked := 0
	for checked < 60 {
		deleted := true
		svc.DescribeNatGatewaysPages(
			&ec2.DescribeNatGatewaysInput{
				Filter: []*ec2.Filter{
					{
						Name: aws.String("vpc-id"),
						Values: []*string{
							aws.String(vpcId),
						},
					},
				},
			},
			func(result *ec2.DescribeNatGatewaysOutput, lastPage bool) bool {
				for _, gateway := range result.NatGateways {
					if *gateway.State != "deleted" {
						deleted = false
						return true
					}
				}
				return !lastPage
			},
		)
		if deleted == true {
			checked = 61
		} else {
			checked += 1
			log.Println("waiting for NAT gateway deletion")
			time.Sleep(10 * time.Second)
		}
	}
	return err
}

func DeleteInternetGateways(vpcId string) error {
	var err error
	svc.DescribeInternetGatewaysPages(
		&ec2.DescribeInternetGatewaysInput{
			Filters: []*ec2.Filter{
				{
					Name: aws.String("attachment.vpc-id"),
					Values: []*string{
						aws.String(vpcId),
					},
				},
			},
		},
		func(result *ec2.DescribeInternetGatewaysOutput, lastPage bool) bool {
			for _, gateway := range result.InternetGateways {
				log.Println("detaching: ", *gateway.InternetGatewayId)
				_, err = svc.DetachInternetGateway(&ec2.DetachInternetGatewayInput{
					InternetGatewayId: gateway.InternetGatewayId,
					VpcId:             aws.String(vpcId),
				})
				if err != nil {
					return false
				}
				log.Println("deleting: ", *gateway.InternetGatewayId)
				_, err = svc.DeleteInternetGateway(&ec2.DeleteInternetGatewayInput{
					InternetGatewayId: gateway.InternetGatewayId,
				})
				if err != nil {
					return false
				}
			}
			return !lastPage
		},
	)
	return err
}

func DeleteSubnets(vpcId string) error {
	var err error
	svc.DescribeSubnetsPages(
		&ec2.DescribeSubnetsInput{
			Filters: []*ec2.Filter{
				{
					Name: aws.String("vpc-id"),
					Values: []*string{
						aws.String(vpcId),
					},
				},
			},
		},
		func(result *ec2.DescribeSubnetsOutput, lastPage bool) bool {
			for _, subnet := range result.Subnets {
				log.Println("deleting: ", *subnet.SubnetId)
				_, err = svc.DeleteSubnet(&ec2.DeleteSubnetInput{
					SubnetId: subnet.SubnetId,
				})
				if err != nil {
					return false
				}
			}
			return !lastPage
		},
	)
	return err
}

func DeleteRouteTables(vpcId string) error {
	var err error
	svc.DescribeRouteTablesPages(
		&ec2.DescribeRouteTablesInput{
			Filters: []*ec2.Filter{
				{
					Name: aws.String("vpc-id"),
					Values: []*string{
						aws.String(vpcId),
					},
				},
			},
		},
		func(result *ec2.DescribeRouteTablesOutput, lastPage bool) bool {
			for _, routeTable := range result.RouteTables {
				main := false
				for _, association := range routeTable.Associations {
					if *association.Main == true {
						main = true
					}
				}
				if !main {
					log.Println("deleting: ", *routeTable.RouteTableId)
					_, err = svc.DeleteRouteTable(&ec2.DeleteRouteTableInput{
						RouteTableId: routeTable.RouteTableId,
					})
					if err != nil {
						return false
					}
				}
			}
			return !lastPage
		},
	)
	return err
}

func DeleteSecurityGroups(vpcId string) error {
	var err error
	svc.DescribeSecurityGroupsPages(
		&ec2.DescribeSecurityGroupsInput{
			Filters: []*ec2.Filter{
				{
					Name: aws.String("vpc-id"),
					Values: []*string{
						aws.String(vpcId),
					},
				},
			},
		},
		func(page *ec2.DescribeSecurityGroupsOutput, lastPage bool) bool {
			for _, sg := range page.SecurityGroups {
				for _, permission := range sg.IpPermissions {
					log.Println("revoking rule from: ", *sg.GroupId)
					_, err = svc.RevokeSecurityGroupIngress(&ec2.RevokeSecurityGroupIngressInput{
						GroupId:       aws.String(*sg.GroupId),
						IpPermissions: []*ec2.IpPermission{permission},
					})
					if err != nil {
						return false
					}
				}

			}
			return !lastPage
		},
	)
	if err != nil {
		return err
	}
	svc.DescribeSecurityGroupsPages(
		&ec2.DescribeSecurityGroupsInput{
			Filters: []*ec2.Filter{
				{
					Name: aws.String("vpc-id"),
					Values: []*string{
						aws.String(vpcId),
					},
				},
			},
		},
		func(page *ec2.DescribeSecurityGroupsOutput, lastPage bool) bool {
			for _, sg := range page.SecurityGroups {
				if *sg.GroupName == "default" {
					continue
				}
				log.Println("deleting: ", *sg.GroupId)
				_, err = svc.DeleteSecurityGroup(&ec2.DeleteSecurityGroupInput{
					GroupId: aws.String(*sg.GroupId),
				})
				if err != nil {
					log.Println(err)
					return false
				}

			}
			return !lastPage
		},
	)
	return err
}
