### CUSTOMIZE_ME: Deploy OpenMetadata on AWS with Terraform

This repository is a Terraform module that deploys OpenMetadata on AWS with flexible provisioners for each component (OpenMetadata app, databases, Airflow, and OpenSearch). Use this guide to customize and deploy it safely.


### What you get
- OpenMetadata deployed to your EKS cluster via Helm.
- Optional AWS-managed services when selected:
  - RDS for OpenMetadata DB and/or Airflow DB
  - OpenSearch domain
  - EFS volumes for Airflow (when Airflow via Helm)
- Kubernetes secrets, storage classes (when Helm), and sensible defaults.


### Prerequisites
- Terraform ~> 1.0, AWS provider ~> 5.x
- AWS CLI configured with credentials and region that can create/manage: VPC, EKS, IAM, RDS, EFS, KMS, OpenSearch, and security groups (depending on what you enable).
- kubectl with access to the target EKS cluster (unless you use the complete example to create one).
- Helm provider usable against the target cluster (the example config wires this automatically).


### Provisioner choices (per component)
- OpenMetadata app: Helm (default)
- OpenMetadata DB: Helm (default), AWS (RDS), or Existing
- Airflow: Helm (default) or Existing
- Airflow DB: Helm (default), AWS (RDS), or Existing
- OpenSearch: Helm (default), AWS (OpenSearch), or Existing

You choose provisioners through variables:
- db.provisioner: "helm" | "aws" | "existing"
- airflow.provisioner: "helm" | "existing"
- airflow.db.provisioner: "helm" | "aws" | "existing"
- opensearch.provisioner: "helm" | "aws" | "existing"

Notes:
- If `airflow.provisioner = "existing"`, then `airflow.db.provisioner` must be `"existing"` as well (enforced by defaults).
- When any component is set to AWS, you must also provide networking and KMS inputs (`eks_nodes_sg_ids`, `subnet_ids`, `vpc_id`, and optionally `kms_key_id`).


### Key inputs you will likely set
- app_namespace: Kubernetes namespace to deploy into (default: "openmetadata")
- app_version / app_helm_chart_version: App and/or chart version (defaults to 1.10.6)
- docker_image_name / docker_image_tag: Optional image override (defaults provided; tag falls back to app_version)
- principal_domain, initial_admins: User bootstrap for OpenMetadata
- env_from, extra_envs: Additional environment configuration for the app
- eks_nodes_sg_ids: Security group IDs on your EKS nodes (used to allow inbound from nodes to RDS/EFS/OpenSearch when using AWS provisioners)
- subnet_ids, vpc_id: Subnets and VPC for AWS resources (recommend private subnets)
- kms_key_id: Optional AWS KMS key ARN for encryption (RDS/EFS/OpenSearch)
- db, airflow.db, opensearch: Component-specific settings (engine/version/storage size/credentials/etc.) varying by provisioner

Refer to `README_terraform.md` for the full input table.


### Secrets behavior (Helm-based defaults)
If you use Helm for databases or Airflow:
- OpenMetadata DB (Helm MySQL): a Kubernetes secret `mysql-secrets` with key `openmetadata-mysql-password` gets created with a default password `openmetadata_password`.
- Airflow auth (Helm): a random password is generated and stored under the secret name/key defined by `airflow.credentials.password.secret_ref` and `secret_key` (defaults to `airflow-auth`/`password`).
- Airflow DB (Helm MySQL): a Kubernetes secret `airflow-mysql-secrets` with key `airflow-mysql-password` set to `airflow_pass`.

If you use AWS or Existing for DB/OpenSearch, provide credentials via `credentials.username` and `credentials.password.secret_ref/secret_key` to reference your own Kubernetes secret(s).


### Two ways to get started

#### Option A) Use the complete example (creates VPC, EKS, KMS, RDS, OpenSearch, EFS, etc.)
Best when you want a full demo or to provision all infra from scratch.

1) Review example and set variables
   - Open `examples/complete/variables.tf` and adjust inputs, or create `examples/complete/terraform.tfvars` with your values (region, cluster name, instance sizes, etc.).

2) Initialize and apply

```bash
cd examples/complete
terraform init
terraform plan
terraform apply

kubectl -n itpipes-openmetadata get pods
kubectl -n itpipes-openmetadata rollout status deploy/openmetadata
kubectl -n itpipes-openmetadata port-forward svc/openmetadata 8585:8585
# Open http://localhost:8585
```



3) Access the UIs

```bash
# OpenMetadata
kubectl port-forward service/openmetadata -n <your-namespace> 8585:8585
# then open http://localhost:8585

# Airflow (when deployed via Helm dependencies)
kubectl port-forward service/openmetadata-deps-web -n <your-namespace> 8080:8080
# then open http://localhost:8080
```

4) Destroy when done (incurs costs otherwise)

```bash
terraform destroy
```

5) Initial OpenMetadata login 

```
admin@open-metadata.org  (no password)
```

6) Access Airflow password for "admin"

```bash
# bash
kubectl -n itpipes-openmetadata get secret itpipes-openmetadata-prod-airflow-auth -o jsonpath='{.data.password}' | base64 -d; echo
```

```powershell
# powershell
$raw = kubectl -n itpipes-openmetadata get secret itpipes-openmetadata-prod-airflow-auth -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($raw))
```


#### Option B) Use this module in your own root with an existing EKS
Best when your cluster already exists and you only need OpenMetadata and dependencies.

1) Create a root folder and minimal providers setup

```hcl
# providers.tf
provider "aws" {
  region = var.region
}

provider "kubernetes" {
  # Example: use your current kubeconfig context, or EKS exec auth
}

provider "helm" {
  kubernetes {
    # Match the same cluster config as the kubernetes provider
  }
}
```

2) Instantiate the module with your chosen provisioners

```hcl
# main.tf
module "openmetadata" {
  # If using this repo locally, use: source = "../" (relative path)
  # If using Registry (recommended), use:
  source  = "open-metadata/openmetadata/aws"
  version = "1.10.6"

  app_namespace    = "openmetadata"
  app_version      = "1.10.6"
  eks_nodes_sg_ids = ["sg-xxxxxxxxxxxxxxxxx"]
  subnet_ids       = ["subnet-aaaaaaaa", "subnet-bbbbbbbb", "subnet-cccccccc"]
  vpc_id           = "vpc-xxxxxxxx"
  kms_key_id       = null # or your KMS ARN

  # Example: production-ready AWS-managed dependencies
  db = {
    provisioner = "aws"
    # optionally override engine/version/size/credentials/etc.
  }
  airflow = {
    provisioner = "helm"
    db = {
      provisioner = "aws"
    }
  }
  opensearch = {
    provisioner = "aws"
    # optionally override domain size/engine version/etc.
  }

  # Optional customizations
  extra_envs = {
    "VAR_1" = "foo"
  }
  env_from = ["my-extra-secret"]
}
```

3) Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

4) Access OpenMetadata and/or Airflow via port-forwarding (same commands as Option A).


### Customization reference

- OpenMetadata app
  - app_namespace, app_version, app_helm_chart_version, docker_image_name, docker_image_tag, principal_domain, initial_admins
  - env_from (list of Kubernetes secrets to import as env), extra_envs (key/value map)

- Databases (OpenMetadata and Airflow)
  - provisioner = "helm" | "aws" | "existing"
  - engine.name ("postgres" or "mysql"), engine.version
  - storage_size, port, db_name
  - credentials.username, credentials.password.secret_ref, credentials.password.secret_key
  - For AWS: instance_class, multi_az, backup windows, deletion protection, etc.

- OpenSearch
  - provisioner = "helm" | "aws" | "existing"
  - For AWS: domain sizing (instance_type/count), engine_version, AZ count, TLS policy
  - For Existing: host, scheme, port, credentials
  - For Helm: volume_size and storage_class (optional)

- Networking and encryption (AWS provisioners)
  - eks_nodes_sg_ids: EKS node security group IDs that must be allowed by RDS/EFS/OpenSearch SGs
  - subnet_ids: Private subnets recommended
  - vpc_id: VPC hosting the subnets
  - kms_key_id: KMS key ARN for encrypting AWS resources (optional; account default used if null)


### Operational notes
- Keep the terminal running `kubectl port-forward` open while accessing the services.
- If a local port is in use, change the first number in the mapping (e.g., `8586:8585`).
- Costs: AWS provisioners create billable resources. Destroy when not needed.
- RBAC/IAM: ensure your AWS principal can create the resources you enable.
- Provider wiring: the module expects working `kubernetes` and `helm` providers pointing to your target cluster. The complete example configures these automatically for the created EKS cluster.


### Troubleshooting
- kubernetes/helm provider authorization errors: confirm your kubeconfig or EKS exec auth is correct and that IAM roles are mapped (aws-auth ConfigMap).
- RDS/OpenSearch creation failures: check VPC/subnets/SGs/KMS permissions and that `eks_nodes_sg_ids` are correct for reachability.
- Helm install failures: ensure the namespace exists and that the helm provider is pointing at the correct cluster/context.
- Secrets not found (Existing provisioners): create the referenced Kubernetes secrets with the names/keys you configured.


### Cleanup
Run from the same working directory you applied from:

```bash
terraform destroy
```


