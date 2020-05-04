package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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

func validateCluster(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")
	waitForCluster(t, kubectlOptions)
	waitForNodes(t, kubectlOptions, 2)
	nodes, err := k8s.GetNodesByFilterE(t, kubectlOptions, metav1.ListOptions{LabelSelector: "node-role.k8s.cookpad.com/critical-addons=true"})
	require.NoError(t, err)
	assert.GreaterOrEqual(t, len(nodes), 2)
	for _, node := range nodes {
		taint := node.Spec.Taints[0]
		assert.Equal(t, "CriticalAddonsOnly", taint.Key)
		assert.Equal(t, "true", taint.Value)
		assert.Equal(t, corev1.TaintEffectNoSchedule, taint.Effect)
	}
}

func validateSecretsBehaviour(t *testing.T, kubeconfig string) {
	namespace := strings.ToLower(random.UniqueId())
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, namespace)
	secretManifest := fmt.Sprintf(EXAMPLE_SECRET, namespace, namespace)
	defer k8s.KubectlDeleteFromString(t, kubectlOptions, secretManifest)
	k8s.KubectlApplyFromString(t, kubectlOptions, secretManifest)
	secret := k8s.GetSecret(t, kubectlOptions, "keys-to-the-kingdom")
	password := secret.Data["password"]
	assert.Equal(t, "Open Sesame", string(password))
}

const EXAMPLE_SECRET = `---
apiVersion: v1
kind: Namespace
metadata:
  name: %s
---
apiVersion: v1
kind: Secret
metadata:
  name: keys-to-the-kingdom
  namespace: %s
type: Opaque
data:
  password: T3BlbiBTZXNhbWU=
`

func validateMetricsServer(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	maxRetries := 20
	sleepBetweenRetries := 6 * time.Second
	retry.DoWithRetry(t, "wait for kubectl top pods to work", maxRetries, sleepBetweenRetries, func() (string, error) {
		return k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "top", "pods")
	})
}

func validateClusterAutoscaler(t *testing.T, kubeconfig string) {
	filters := metav1.ListOptions{
		LabelSelector: "app.kubernetes.io/name=aws-cluster-autoscaler",
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
		LabelSelector: "app=test-workload",
	}
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, 6, 1, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 12, 10*time.Second)
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
  name: test-workload-deployment
  namespace: %s
  labels:
    app: test-workload
spec:
  replicas: 6
  selector:
    matchLabels:
      app: test-workload
  template:
    metadata:
      labels:
        app: test-workload
    spec:
      containers:
      - name: workload
        image: 602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/pause-amd64:3.1
        resources:
          requests:
            cpu: "1100m"
`

func validateNodeTerminationHandler(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	nodes := k8s.GetNodes(t, kubectlOptions)
	filters := metav1.ListOptions{
		LabelSelector: "k8s-app=aws-node-termination-handler",
	}

	// Check that the handler is running on all the nodes
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, len(nodes), 6, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}
}

func validateNodeExporter(t *testing.T, kubeconfig string) {
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "kube-system")
	nodes := k8s.GetNodes(t, kubectlOptions)
	filters := metav1.ListOptions{
		LabelSelector: "app=prometheus-node-exporter",
	}

	// Check that the exporter is running on all the nodes
	k8s.WaitUntilNumPodsCreated(t, kubectlOptions, filters, len(nodes), 6, 10*time.Second)
	for _, pod := range k8s.ListPods(t, kubectlOptions, filters) {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, 6, 10*time.Second)
	}
}

func writeKubeconfig(t *testing.T, opts ...string) string {
	file, err := ioutil.TempFile(os.TempDir(), "kubeconfig-")
	require.NoError(t, err)
	args := []string{
		"eks",
		"update-kubeconfig",
		"--name", opts[0],
		"--kubeconfig", file.Name(),
		"--region", "us-east-1",
	}
	if len(opts) > 1 {
		args = append(args, "--role-arn", opts[1])
	}
	shell.RunCommand(t, shell.Command{
		Command: "aws",
		Args:    args,
	})
	return file.Name()
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
