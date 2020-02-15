/*
  Control Plane Security Group
*/

resource "aws_security_group" "control_plane" {
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
  And rules to control comunication between nodes and cluster.
*/

resource "aws_security_group" "node" {
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
}

resource "aws_security_group_rule" "node-ingress-self" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.control_plane.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.control_plane.id
  source_security_group_id = aws_security_group.node.id
  type                     = "ingress"
}

/*
  EKS control plane
*/

data "aws_iam_role" "service_role" {
  name = var.iam_config.service_role
}

resource "aws_eks_cluster" "control_plane" {
  name     = var.name
  role_arn = data.aws_iam_role.service_role.arn

  version = var.k8s_version

  enabled_cluster_log_types = var.cluster_log_types

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    security_group_ids      = [aws_security_group.control_plane.id]
    subnet_ids              = concat(values(var.vpc_config.public_subnet_ids), values(var.vpc_config.private_subnet_ids))
  }

  depends_on = [aws_cloudwatch_log_group.control_plane]

  provisioner "local-exec" {
    # wait for api to be avalible for use by the kubernetes provider before continuing
    command     = "until curl --output /dev/null --insecure --silent ${self.endpoint}/healthz; do sleep 1; done"
    working_dir = path.module
  }
}

resource "aws_iam_openid_connect_provider" "cluster_oidc" {
  url             = aws_eks_cluster.control_plane.identity.0.oidc.0.issuer
  thumbprint_list = var.oidc_root_ca_thumbprints
  client_id_list  = ["sts.amazonaws.com"]
}

resource "aws_cloudwatch_log_group" "control_plane" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = 7
}

/*
  Allow nodes to join the cluster
*/

data "aws_eks_cluster_auth" "control_plane" {
  name = var.name
}

provider "kubernetes" {
  version                = "1.10.0"
  host                   = aws_eks_cluster.control_plane.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.control_plane.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.control_plane.token
  load_config_file       = false
}

data "aws_iam_role" "node_role" {
  name = var.iam_config.node_role
}

resource "kubernetes_config_map" "aws-auth" {
  provider = kubernetes

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(
      [
        {
          "rolearn" : data.aws_iam_role.node_role.arn
          "username" : "system:node:{{EC2PrivateDNSName}}"
          "groups" : [
            "system:bootstrappers",
            "system:nodes",
          ],
        },
      ],
    )
  }
}
