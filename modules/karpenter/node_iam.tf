resource "aws_iam_role" "karpenter_node" {
  name               = "${var.cluster_config.iam_role_name_prefix}KarpenterNode-${var.cluster_config.name}"
  assume_role_policy = data.aws_iam_policy_document.karpenter_node_assume_role_policy.json
  description        = "Karpenter node role for ${var.cluster_config.name} cluster"
}

data "aws_iam_policy_document" "karpenter_node_assume_role_policy" {
  statement {
    sid     = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "karpenter_node_managed_policies" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.karpenter_node.id
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = aws_iam_role.karpenter_node.name
  role = aws_iam_role.karpenter_node.name
}
