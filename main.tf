/*
  Control Plane Security Group
*/

resource "aws_security_group" "control_plane" {
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


resource "aws_eks_cluster" "control_plane" {
  name     = var.name
  role_arn = data.aws_iam_role.eks_service_role.arn

  version = var.k8s_version

  vpc_config {
    security_group_ids = [aws_security_group.control_plane.id]
    subnet_ids         = var.subnet_ids
  }
}

/*
  Template a kubeconfig, for testing etc.
*/
data "template_file" "kubeconfig" {
  template = <<YAML
apiVersion: v1
kind: Config
clusters:
- name: $${cluster_name}
  cluster:
    certificate-authority-data: $${ca_data}
    server: $${endpoint}
users:
- name: $${cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
      - "eks"
      - "get-token"
      - "--cluster-name"
      - "$${cluster_name}"
contexts:
- name: $${cluster_name}
  context:
    cluster: $${cluster_name}
    user: $${cluster_name}
current-context: $${cluster_name}
YAML


  vars = {
    cluster_name = var.name
    ca_data      = aws_eks_cluster.control_plane.certificate_authority[0].data
    endpoint     = aws_eks_cluster.control_plane.endpoint
  }
}
