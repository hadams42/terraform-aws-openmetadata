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
      identifier = var.db_identifier
    }
  }
  airflow = {
    provisioner = "helm"
    db = {
      provisioner = "aws"
      db_name     = var.airflow_db_name
      aws = {
        identifier = var.airflow_db_identifier
      }
    }
  }
  opensearch = {
    provisioner = "aws"
    aws = {
      domain_name = var.opensearch_domain_name
    }
  }

  # Entra ID (Azure AD) OIDC configuration
  env_from = ["om-auth"]
  extra_envs = {
    AUTHENTICATION_PROVIDER         = "azure"
    AUTHENTICATION_AUTHORITY        = "https://login.microsoftonline.com/${var.authentication_tenant_id}/v2.0"
    AUTHENTICATION_PUBLIC_KEY_URLS  = "https://login.microsoftonline.com/${var.authentication_tenant_id}/discovery/v2.0/keys"
    AUTHENTICATION_CLIENT_ID        = var.authentication_client_id
    AUTHENTICATION_CALLBACK_URL     = var.authentication_callback_url
    JWT_PRINCIPAL_CLAIM             = "email"
  }

  depends_on = [
    kubernetes_namespace_v1.app,
    kubernetes_secret_v1.om_auth
  ]

}


