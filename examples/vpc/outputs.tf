output "vpc_id" {
  value = module.vpc.config.vpc_id
}

output "public_subnet_ids" {
  value = values(module.vpc.config.public_subnet_ids)
}

output "private_subnet_ids" {
  value = values(module.vpc.config.private_subnet_ids)
}
