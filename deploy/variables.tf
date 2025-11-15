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


