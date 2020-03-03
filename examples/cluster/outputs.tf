output "kubeconfig" {
  value = data.template_file.kubeconfig.rendered
}

output "cluster_name" {
  value = var.cluster_name
}

output "test_role_kubeconfig" {
  value = data.template_file.test_role_kubeconfig.rendered
}
