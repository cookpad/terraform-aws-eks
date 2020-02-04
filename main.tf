/*
  Control Plane Security Group
*/

resource "aws_security_group" "control-plane" {
  name        = "eks-control-plane-${var.name}"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

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
  EKS control plane
*/

data "aws_iam_role" "eks_service_role" {
  name = var.eks_service_role
}


resource "aws_eks_cluster" "control-plane" {
  name     = var.name
  role_arn = data.aws_iam_role.eks_service_role.arn

  version = var.k8s_version

  vpc_config {
    security_group_ids = [aws_security_group.control-plane.id]
    subnet_ids         = var.subnet_ids
  }
}
