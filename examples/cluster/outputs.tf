output "kubeconfig" {
  value = data.template_file.kubeconfig.rendered
}

output "cluster_name" {
  value = var.cluster_name
}
