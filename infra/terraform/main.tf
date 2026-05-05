provider "kubernetes" {
  config_path = var.kubeconfig_path
}

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

resource "kubernetes_namespace_v1" "env" {
  for_each = var.environments

  metadata {
    name = each.value
    labels = {
      "managed-by" = "terraform"
      "project"    = "circleguard"
      "env"        = each.value
    }
  }
}

resource "kubernetes_secret_v1" "dockerhub_pull_secret" {
  for_each = var.environments

  metadata {
    name      = "dockerhub-pull-secret"
    namespace = kubernetes_namespace_v1.env[each.key].metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.dockerconfigjson
  }
}

resource "kubernetes_secret_v1" "qr_secret" {
  for_each = var.environments

  metadata {
    name      = "qr-secret"
    namespace = kubernetes_namespace_v1.env[each.key].metadata[0].name
  }

  data = {
    qr_secret = var.qr_secret
  }

  type = "Opaque"
}
