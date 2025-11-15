module "openmetadata" {
  # Use the module from the repository root (this folder sits inside the repo)
  source = "../"

  # Kubernetes namespace for OpenMetadata resources
  app_namespace = var.app_namespace

  # Networking required for AWS-managed deps and for Airflow (Helm) EFS volumes
  vpc_id           = var.vpc_id
  subnet_ids       = var.subnet_ids
  eks_nodes_sg_ids = var.eks_nodes_sg_ids
  kms_key_id       = var.kms_key_id

  depends_on = [
    kubernetes_namespace_v1.app
  ]

}


