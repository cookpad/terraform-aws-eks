output "vpc_id" {
  value = module.vpc.config.vpc_id
}

output "vpc_config" {
  value = module.vpc.config
}

output "iam_config" {
  value = module.iam.config
}
