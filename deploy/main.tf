module "openmetadata" {
  # Use the module from the repository root (this folder sits inside the repo)
  source = "../"

  # Kubernetes namespace for OpenMetadata resources
  app_namespace = var.app_namespace
  principal_domain = var.principal_domain
  initial_admins   = var.initial_admins

  # Networking required for AWS-managed deps and for Airflow (Helm) EFS volumes
  vpc_id           = var.vpc_id
  subnet_ids       = var.subnet_ids
  # Use the EKS cluster security group so DB/OpenSearch allow traffic from nodes
  eks_nodes_sg_ids = [local.eks_nodes_sg_id]
  kms_key_id       = var.kms_key_id

  # Switch dependencies to AWS-managed services
  db = {
    provisioner = "aws"
    db_name     = var.db_name
    aws = {
      identifier          = var.db_identifier
      deletion_protection = false
    }
  }
  airflow = {
    provisioner = "helm"
    db = {
      provisioner = "aws"
      db_name     = var.airflow_db_name
      aws = {
        identifier          = var.airflow_db_identifier
        deletion_protection = false
      }
    }
  }
  opensearch = {
    provisioner = "aws"
    aws = {
      domain_name = var.opensearch_domain_name
    }
  }

  # Use OpenMetadata Basic Auth as described in the docs:
  # https://docs.open-metadata.org/latest/deployment/security/basic-auth
  # Authentication provider is set via environment variable, while
  # admin principals and principal domain are provided through Helm values.
  env_from = []
  extra_envs = {
    AUTHENTICATION_PROVIDER = "basic"
  }

  depends_on = [
    kubernetes_namespace_v1.app,
    aws_eks_addon.efs_csi
  ]

}


