output "config" {
  value = {
    service_role = aws_iam_role.eks_service_role.name
    node_role    = aws_iam_role.eks_node.name
  }
}
