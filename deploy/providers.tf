terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
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
  # Uses your default kubeconfig context
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}


