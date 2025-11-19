terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Version is constrained in the root module; keep it flexible here.
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      itp_client_account_name   = "ITpipes internal"
      itp_client_account_id     = "001JR00000bJwkaYAC"
      itp_client_account_status = "active"
    }
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.openmetadata.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.openmetadata.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.openmetadata.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.openmetadata.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.region]
    }
  }
}
