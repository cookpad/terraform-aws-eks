package test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	authv1 "k8s.io/api/authorization/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestTerraformAwsEksCluster(t *testing.T) {
	t.Parallel()

	environmentDir := "../examples/cluster/environment"
	workingDir := "../examples/cluster"

	// At the end of the test, run `terraform destroy` to clean up any resources that were created.
	defer test_structure.RunTestStage(t, "cleanup_terraform", func() {
		cleanupTerraform(t, workingDir)
		cleanupTerraform(t, environmentDir)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		uniqueId := random.UniqueId()
		clusterName := fmt.Sprintf("terraform-aws-eks-testing-%s", uniqueId)
		vpcCidr := aws.GetRandomPrivateCidrBlock(18)
		deployTerraform(t, environmentDir, map[string]interface{}{
			"cluster_name": clusterName,
			"cidr_block":   vpcCidr,
		})
		deployTerraform(t, workingDir, map[string]interface{}{
			"cluster_name": clusterName,
		})
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"))
		defer os.Remove(kubeconfig)
		validateCluster(t, kubeconfig)
		validateSecretsBehaviour(t, kubeconfig)
		validateDNS(t, kubeconfig)
		validateMetricsServer(t, kubeconfig)
		validateClusterAutoscaler(t, kubeconfig)
		validateNodeLabels(t, kubeconfig, terraform.Output(t, terraformOptions, "cluster_name"))
		validateNodeTerminationHandler(t, kubeconfig)
		validateNodeExporter(t, kubeconfig)
		admin_kubeconfig := writeKubeconfig(t, terraform.Output(t, terraformOptions, "cluster_name"), terraform.Output(t, terraformOptions, "test_role_arn"))
		defer os.Remove(admin_kubeconfig)
		validateAdminRole(t, admin_kubeconfig)
	})
}

func validateNodeLabels(t *testing.T, kubeconfig string, clusterName string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-role.kubernetes.io/spot-worker=true"})
	require.NoError(t, err)
	for _, node := range nodes {
		assert.Equal(t, clusterName, node.Labels["cookpad.com/terraform-aws-eks-test-environment"])
	}
}

func validateAdminRole(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	k8s.CanIDo(t, kubectlOptions, authv1.ResourceAttributes{
		Namespace: "*",
		Verb:      "*",
		Group:     "*",
		Version:   "*",
	})
}

func validateDNS(t *testing.T, kubeconfig string) {
	nameSuffix := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	test := fmt.Sprintf(DNS_TEST_JOB, nameSuffix)
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, test)
	k8s.KubectlApplyFromString(t, kubectlOptions, test)
	WaitUntilPodsSucceeded(t, kubectlOptions, metav1.ListOptions{LabelSelector: "job-name=nslookup-" + nameSuffix}, 1, 30, 10*time.Second)
}

const DNS_TEST_JOB = `---
apiVersion: batch/v1
kind: Job
metadata:
  name: nslookup-%s
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: dnsutils
        image: gcr.io/kubernetes-e2e-test-images/dnsutils:1.3
        command:
          - nslookup
          - kubernetes.default
        imagePullPolicy: IfNotPresent
      restartPolicy: Never
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
  backoffLimit: 4
`
