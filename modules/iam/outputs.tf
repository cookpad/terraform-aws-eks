output "config" {
  value = {
    service_role = aws_iam_role.eks_service_role.name
    node_role    = aws_iam_role.eks_node.name
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node.policy_arn,
    aws_iam_role_policy_attachment.eks_cni.policy_arn,
    aws_iam_role_policy_attachment.ecr.policy_arn,
    aws_iam_role_policy_attachment.eks_service_policy.policy_arn,
    aws_iam_role_policy_attachment.eks_cluster_policy.policy_arn,
  ]
}
