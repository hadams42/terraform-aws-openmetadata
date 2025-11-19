variable "region" {
  description = "AWS region for the providers (e.g., us-east-1)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for AWS-managed resources and Airflow (Helm) EFS."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs used by AWS-managed resources and EFS mount targets."
  type        = list(string)
}

variable "kms_key_id" {
  description = "Optional KMS key ARN for encryption of AWS resources."
  type        = string
  default     = null
}

variable "app_namespace" {
  description = "Kubernetes namespace to deploy OpenMetadata into."
  type        = string
  default     = "openmetadata"
}

variable "principal_domain" {
  description = "Domain name of users for OpenMetadata (e.g., itpipes.com)."
  type        = string
  default     = "itpipes.com"
}

variable "initial_admins" {
  description = "List of initial admin usernames (without domain), as a string list literal. Example: \"[admin]\"."
  type        = string
  default     = "[admin]"
}

variable "authentication_tenant_id" {
  description = "Azure Entra ID (Azure AD) Tenant ID for OIDC."
  type        = string
}

variable "authentication_client_id" {
  description = "Azure Entra ID application (client) ID for OpenMetadata OIDC."
  type        = string
}

variable "authentication_client_secret" {
  description = "Azure Entra ID application client secret for OpenMetadata OIDC."
  type        = string
  sensitive   = true
}

variable "authentication_callback_url" {
  description = "OpenMetadata OIDC callback URL (e.g., http://localhost:8585/callback or https://openmetadata.yourdomain/callback)."
  type        = string
  default     = "http://localhost:8585/callback"
}

variable "db_name" {
  description = "Database name for the OpenMetadata RDS instance (AWS provisioner). Must be alphanumeric and start with a letter."
  type        = string
  default     = "openmetadata"
}

variable "db_identifier" {
  description = "Identifier for the OpenMetadata RDS instance (optional)."
  type        = string
  default     = null
}

variable "airflow_db_name" {
  description = "Database name for the Airflow RDS instance (AWS provisioner). Must be alphanumeric and start with a letter."
  type        = string
  default     = "airflow"
}

variable "airflow_db_identifier" {
  description = "Identifier for the Airflow RDS instance (optional)."
  type        = string
  default     = null
}

variable "opensearch_domain_name" {
  description = "AWS OpenSearch domain name (lowercase letters, numbers, hyphens; 3-28 chars, starts with a letter)."
  type        = string
  default     = "itpipes-openmetadata"
}

variable "eks_cluster_name" {
  description = "Name for the EKS cluster to create."
  type        = string
}


