resource "aws_iam_role" "karpenter_node" {
  name                 = "${var.iam_role_name_prefix}KarpenterNode-${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.karpenter_node_assume_role_policy.json
  description          = "Karpenter node role for ${var.name} cluster"
}

data "aws_iam_policy_document" "karpenter_node_assume_role_policy" {
  statement {
    sid = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "managed_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role = aws_iam_role.karpenter_node.id
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = aws_iam_role.karpenter_node.name
  role = aws_iam_role.karpenter_node.name
}
