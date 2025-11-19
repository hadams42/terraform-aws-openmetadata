locals {
  eks_nodes_managed_policies = [
    "AmazonEC2ContainerRegistryReadOnly",
    "AmazonEKS_CNI_Policy",
    "AmazonEKSWorkerNodePolicy",
  ]
}

# IAM role for the EKS control plane
resource "aws_iam_role" "eks_cluster" {
  name = "om-eks-cluster"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowEKSService"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM role for EKS managed node group
resource "aws_iam_role" "eks_nodes" {
  name = "om-eks-nodes"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeRole"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each = toset(local.eks_nodes_managed_policies)

  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}


