resource "kubernetes_secret_v1" "om_auth" {
  metadata {
    name      = "om-auth"
    namespace = var.app_namespace
  }

  data = {
    "AUTHENTICATION_CLIENT_SECRET" = var.authentication_client_secret
  }
}


