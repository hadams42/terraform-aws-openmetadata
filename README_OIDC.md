### OpenMetadata OIDC (Azure Entra ID) Setup

This guide explains how to connect this OpenMetadata deployment to your SSO using Azure Entra ID (Azure AD), and what to configure in AWS/EKS and in the `deploy/` stack of this repo.


### Overview
- The app (OpenMetadata) runs in your EKS cluster.
- OIDC (Azure Entra ID) is used for user authentication to the OpenMetadata UI.
- The `deploy/` stack wires OIDC via environment variables and a Kubernetes secret (created by Terraform).


### 1) Azure (Entra ID) Configuration
1) Register a new application
   - Azure Portal → Microsoft Entra ID → App registrations → New registration.
   - Name: “OpenMetadata” (or your preferred name)
   - Supported account types: Choose as required.
   - Redirect URI (Web):
     - Production: `https://<your-openmetadata-host>/callback`
     - Local testing (port-forward): `http://localhost:8585/callback`

2) Enable ID tokens and configure claims
   - Authentication → “ID tokens” (OpenID Connect) must be enabled.
   - Ensure the email (or a mapped claim that represents user email) is included in tokens. The deployment expects `JWT_PRINCIPAL_CLAIM=email`.

3) Create a client secret
   - Certificates & secrets → New client secret.
   - Copy the secret value (store it securely). You will put this in Terraform.

4) Collect Azure details for Terraform
   - Tenant ID
   - Application (client) ID
   - Client secret (created above)
   - Callback URL (must match exactly what you registered)

Notes
- OpenMetadata uses Azure v2 endpoints. We build these automatically using your Tenant ID:
  - Authority: `https://login.microsoftonline.com/<TENANT_ID>/v2.0`
  - JWKS URL: `https://login.microsoftonline.com/<TENANT_ID>/discovery/v2.0/keys`


### 2) AWS/EKS Considerations (network & exposure)
- EKS cluster access must be configured for Terraform’s Kubernetes/Helm providers (already done in `deploy/providers.tf` using your kubeconfig).
- For production, you’ll typically expose the service publicly (Ingress/ALB or Service type=LoadBalancer) so your callback URL is a public HTTPS URL:
  - Example: Use AWS Load Balancer Controller or your Ingress of choice to expose `svc/openmetadata`.
  - Update the Azure Redirect URI and `authentication_callback_url` in Terraform to the public URL once available.
- If you’re testing locally with `kubectl port-forward`, use `http://localhost:8585/callback` in both Azure and Terraform.


### 3) Configure the deploy/ stack
All customizations are centralized in `deploy/terraform.tfvars`. Fill in these values:

```hcl
# Required: your namespace and identity settings
app_namespace          = "itpipes-openmetadata"
principal_domain       = "itpipes.com"
initial_admins         = "[admin]"

# Entra ID (Azure AD) OIDC
authentication_tenant_id     = "<TENANT_ID>"
authentication_client_id     = "<CLIENT_ID>"
authentication_client_secret = "<CLIENT_SECRET>"   # sensitive
authentication_callback_url  = "https://<your-openmetadata-host>/callback" # or http://localhost:8585/callback

# Networking for AWS-managed resources (already present in your tfvars)
region               = "us-west-2"
vpc_id               = "vpc-xxxxxxxx"
subnet_ids           = ["subnet-aaaa", "subnet-bbbb"]
eks_nodes_sg_ids     = ["sg-xxxxxxxx"]
kms_key_id           = null

# AWS-managed dependencies (already wired in deploy/main.tf)
db_name                = "openmetadataprod"
airflow_db_name        = "airflow"
opensearch_domain_name = "itpipes-openmetadata"
```

What the deploy stack does
- `deploy/oidc.tf` creates a Kubernetes secret `om-auth` in your namespace that stores `AUTHENTICATION_CLIENT_SECRET`.
- `deploy/main.tf` sets OIDC env vars for OpenMetadata:
  - `AUTHENTICATION_PROVIDER="azure"`
  - `AUTHENTICATION_AUTHORITY` and `AUTHENTICATION_PUBLIC_KEY_URLS` (derived from your Tenant ID)
  - `AUTHENTICATION_CLIENT_ID`, `AUTHENTICATION_CALLBACK_URL`, `JWT_PRINCIPAL_CLAIM="email"`
  - `env_from = ["om-auth"]` to mount the client secret from the Kubernetes secret

You do not need to create any secrets manually; Terraform handles it.


### 4) Apply changes
```bash
cd deploy
terraform init
terraform plan -out tfplan
terraform apply "tfplan"
```

Wait for the deployment to roll out:
```bash
kubectl -n itpipes-openmetadata get pods
kubectl -n itpipes-openmetadata rollout status deploy/openmetadata
```


### 5) Test SSO
- Local test:
  ```bash
  kubectl -n itpipes-openmetadata port-forward svc/openmetadata 8585:8585
  # Visit http://localhost:8585 and choose “Sign in with Azure”
  ```

- Production:
  - Visit `https://<your-openmetadata-host>` and sign in with Azure.
  - First admin will be `<user>@<principal_domain>` (e.g., `admin@itpipes.com`) as configured by `principal_domain` and `initial_admins`.


### Troubleshooting
- “Login loops” or “invalid redirect URI”:
  - Ensure the Azure App’s Redirect URI matches `authentication_callback_url` exactly (scheme/host/path).
  - If you switch from localhost to a public URL, update both Azure and Terraform.
- “User not found / email missing”:
  - Confirm the ID token contains an `email` claim; otherwise adjust Azure claims mapping or set `JWT_PRINCIPAL_CLAIM` to a claim you know is present.
- 401s after login:
  - Check OpenMetadata pod logs for auth errors and verify Tenant ID, Client ID, and Secret are correct.
- Namespace/service not found:
  - Verify the namespace in your `terraform.tfvars` and your kubectl commands match (default in this repo is `itpipes-openmetadata`).


### Security considerations
- Keep `authentication_client_secret` in Terraform variable files stored securely (or use a secure var store/CI secret store).
- Use HTTPS for production callback and public URLs; configure Ingress/ALB with valid TLS.
- Consider restricting who can sign in via Entra ID conditional access or assign users/groups to the app’s Enterprise Application.


### Migration notes (if you previously customized root defaults)
- The `deploy/` stack now centralizes environment-specific customization. Avoid editing `defaults.tf` in the root for per-environment values.
- Prefer setting variables in `deploy/terraform.tfvars` so they are all in one place and versionable per environment.


