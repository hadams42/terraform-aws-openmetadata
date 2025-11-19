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
  eks_nodes_sg_ids = var.eks_nodes_sg_ids
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

  # Temporary: disable SSO so we can configure Azure in the UI
  # (we'll switch this back to "azure" after UI configuration)
  env_from = []
  extra_envs = {
    AUTHENTICATION_PROVIDER = "no_auth"
  }

  depends_on = [
    kubernetes_namespace_v1.app,
    kubernetes_secret_v1.om_auth,
    aws_eks_addon.efs_csi
  ]

}


