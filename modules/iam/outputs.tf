output "config" {
  value = {
    service_role_arn = aws_iam_role.eks_service_role.arn
    node_role_arn    = aws_iam_role.eks_node.arn
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr,
    aws_iam_role_policy_attachment.eks_service_policy,
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}
