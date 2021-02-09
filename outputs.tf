output "vpc_config" {
  value = module.vpc.config
}

output "iam_config" {
  value = module.iam.config
}

output "cluster_config" {
  value = module.cluster.config
}

output "oidc_config" {
  value = module.cluster.oidc_config
}
