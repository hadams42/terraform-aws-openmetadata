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

variable "eks_nodes_sg_ids" {
  description = "Security group IDs attached to the EKS nodes (allow inbound from nodes)."
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


