resource "aws_eks_fargate_profile" "critical_pods" {
  cluster_name           = var.cluster_config.name
  fargate_profile_name   = "${var.cluster_config.name}-karpenter"
  pod_execution_role_arn = var.cluster_config.fargate_execution_role_arn
  subnet_ids             = values(var.cluster_config.private_subnet_ids)

  selector {
    namespace = "karpenter"
    labels    = {}
  }
}
