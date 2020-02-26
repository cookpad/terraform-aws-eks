package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		kubeconfig, err := writeKubeconfig(terraform.Output(t, terraformOptions, "kubeconfig"))
		if err != nil {
			t.Error("Error writing kubeconfig file:", err)
		}
		defer os.Remove(kubeconfig)
		validateCluster(t, kubeconfig)
		validateClusterAutoscaler(t, kubeconfig)
		validateNodeLabels(t, kubeconfig, terraform.Output(t, terraformOptions, "cluster_name"))
	})
}

func validateCluster(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	waitForCluster(t, kubectlOptions)
	waitForNodes(t, kubectlOptions, 2)
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-role.kubernetes.io/critical-addons=true"})
	require.NoError(t, err)
	assert.Equal(t, 2, len(nodes))
	for _, node := range nodes {
		taint := node.Spec.Taints[0]
		assert.Equal(t, "CriticalAddonsOnly", taint.Key)
		assert.Equal(t, "true", taint.Value)
		assert.Equal(t, corev1.TaintEffectNoSchedule, taint.Effect)
	}
}

func validateNodeLabels(t *testing.T, kubeconfig string, clusterName string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-role.kubernetes.io/spot-worker=true"})
	require.NoError(t, err)
	for _, node := range nodes {
		assert.Equal(t, clusterName, node.Labels["cookpad.com/terraform-aws-eks-test-environment"])
	}
}

func validateClusterAutoscaler(t *testing.T, kubeconfig string) {
	filters := metav1.ListOptions{
		LabelSelector: "app=cluster-autoscaler",
	}

	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")

	// Check that the autoscaler pods are running
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 1, 1, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}

	// Generate some example workload
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions = k8s.NewKubectlOptions("", kubeconfig, namespace)
	workload := fmt.Sprintf(EXAMPLE_WORKLOAD, namespace, namespace)
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, workload)
	k8s.KubectlApplyFromString(t, kubectlOptions, workload)

	// Check the cluster scales up
	waitForNodes(t, kubectlOptions, 6)

	// Check that the example workload pods can all run
	filters = metav1.ListOptions{
		LabelSelector: "app=nginx",
	}
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 6, 1, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}
}

const EXAMPLE_WORKLOAD = `---
apiVersion: v1
kind: Namespace
metadata:
  name: %s
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: %s
  labels:
    app: nginx
spec:
  replicas: 6
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        resources:
          requests:
            cpu: "1100m"
`

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

func waitForCluster(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	maxRetries := 40
	sleepBetweenRetries := 10 * time.Second
	retry.DoWithRetry(t, "Check that access to the k8s api works", maxRetries, sleepBetweenRetries, func() (string, error) {
		// Try an operation on the API to check it works
		_, err := k8s.GetServiceAccountE(t, kubectlOptions, "default")
		return "", err
	})

}

func waitForNodes(t *testing.T, kubectlOptions *k8s.KubectlOptions, numNodes int) {
	maxRetries := 40
	sleepBetweenRetries := 10 * time.Second
	retry.DoWithRetry(t, "wait for nodes to launch", maxRetries, sleepBetweenRetries, func() (string, error) {
		nodes, err := k8s.GetNodesE(t, kubectlOptions)

		if err != nil {
			return "", err
		}

		// Wait for at least n nodes to start
		if len(nodes) < numNodes {
			return "", fmt.Errorf("less than %d nodes started", numNodes)
		}

		return "", err
	})

	// Wait for the nodes to be ready
	k8s.WaitUntilAllNodesReady(t, kubectlOptions, maxRetries, sleepBetweenRetries)
}
