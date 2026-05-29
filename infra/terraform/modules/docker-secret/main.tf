locals {
  dockerconfigjson = jsonencode({
    auths = {
      (var.dockerhub_server) = {
        username = var.dockerhub_username
        password = var.dockerhub_password
        email    = var.dockerhub_email
        auth     = base64encode("${var.dockerhub_username}:${var.dockerhub_password}")
      }
    }
  })
}

resource "kubernetes_secret_v1" "dockerhub_pull_secret" {
  for_each = var.namespaces

  metadata {
    name      = "dockerhub-pull-secret"
    namespace = each.value
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.dockerconfigjson
  }
}
