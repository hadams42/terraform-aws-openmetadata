locals {
  eks_cluster_name              = var.eks_cluster_name
  eks_version                   = "1.33"
  eks_cidr                      = "10.100.0.0/24"
  eks_node_group_instance_types = ["t3.xlarge"]
  eks_nodes_disk_size           = 20
}

# Security group for EKS nodes, used by RDS/OpenSearch/EFS security groups
resource "aws_security_group" "eks_nodes" {
  name        = "${local.eks_cluster_name}-nodes"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EKS cluster
resource "aws_eks_cluster" "openmetadata" {
  name   = local.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  bootstrap_self_managed_addons = true
  version                       = local.eks_version
  enabled_cluster_log_types     = []

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = local.eks_cidr
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_nodes.id]
    endpoint_private_access = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }
}

# EKS managed node group
resource "aws_eks_node_group" "nodes" {
  cluster_name    = local.eks_cluster_name
  # Use a name derived from the cluster so replacements can safely create a
  # new node group without colliding with an existing one that used a
  # different name (e.g., a previous \"eks-nodes\" group).
  node_group_name = "${local.eks_cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  disk_size      = local.eks_nodes_disk_size
  instance_types = local.eks_node_group_instance_types
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  # When changing fields that force replacement (such as ami_type),
  # destroy the old node group before creating the new one to avoid
  # name conflicts in EKS (NodeGroup already exists).
  lifecycle {
    create_before_destroy = false
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_eks_cluster.openmetadata]
}


