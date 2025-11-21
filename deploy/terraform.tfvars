eks_cluster_name = "itpipes-openmetadata-eks"
region           = "us-west-2"
vpc_id           = "vpc-9866edfd"
subnet_ids       = ["subnet-0280dc2dde822719f", "subnet-0b14da0bd3e92d0a3"]
kms_key_id       = null

app_namespace        = "itpipes-openmetadata"
principal_domain     = "itpipes.com"
initial_admins       = "[admin]"
opensearch_domain_name = "itpipes-openmetadata"

