output "cluster_name" {
  value = var.cluster_name
}

output "test_role_arn" {
  value = aws_iam_role.test_role.arn
}

output "cluster_config" {
  value     = module.cluster.config
  sensitive = true
}

output "node_security_group_name" {
  value = data.aws_security_group.nodes.name
}
