/*
  Control Plane Security Group
*/

resource "aws_security_group" "control_plane" {
  count = var.legacy_security_groups ? 1 : 0

  name        = "eks-control-plane-${var.name}"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_config.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-control-plane-${var.name}"
  }
}

/*
  Nodes Security Group
  And rules to control communication between nodes and cluster.

  
*/

resource "aws_security_group" "node" {
  count = var.legacy_security_groups ? 1 : 0

  name        = "eks-node-${var.name}"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc_config.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"                              = "eks-node-${var.name}"
    "kubernetes.io/cluster/${var.name}" = "owned"
  }

  # Remove any stale eni's created by vpc-cni-k8s, so we can remove the node security group
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
      for ID in $(aws ec2 describe-network-interfaces --region ${split(":", self.arn)[3]} --filters 'Name=group-id,Values=${self.id}' 'Name=status,Values=available' 'Name=tag-key,Values=node.k8s.amazonaws.com/instance_id' --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)
      do
        aws ec2 delete-network-interface --region ${split(":", self.arn)[3]} --network-interface-id $ID
      done
    EOF
  }
}

resource "aws_security_group_rule" "node_ingress_self" {
  count = var.legacy_security_groups ? 1 : 0

  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node[count.index].id
  source_security_group_id = aws_security_group.node[count.index].id
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  count = var.legacy_security_groups ? 1 : 0

  description              = "Allow nodes to communicate with nodes and the cluster in the cluster security group"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_eks_cluster.control_plane.vpc_config.0.cluster_security_group_id
  source_security_group_id = aws_security_group.node[count.index].id
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_ingress_node" {
  count = var.legacy_security_groups ? 1 : 0

  description              = "Allow cluster (and nodes) in the cluster security group nodes to communicate with nodes"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node[count.index].id
  source_security_group_id = aws_eks_cluster.control_plane.vpc_config.0.cluster_security_group_id
  type                     = "ingress"
}
