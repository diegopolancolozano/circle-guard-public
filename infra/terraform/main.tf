// Kubernetes provider: if use_gke=true, configure from GKE data sources (requires
// GOOGLE_APPLICATION_CREDENTIALS or provider "google" configured). Otherwise use
// the local kubeconfig file given by `kubeconfig_path`.
data "google_client_config" "current" {}

data "google_container_cluster" "cluster" {
  count    = var.use_gke ? 1 : 0
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = var.gcp_project
}

provider "kubernetes" {
  # When using GKE we set host/token/ca; otherwise we load from kubeconfig_path.
  host = var.use_gke ? "https://${data.google_container_cluster.cluster[0].endpoint}" : null
  token = var.use_gke ? data.google_client_config.current.access_token : null
  cluster_ca_certificate = var.use_gke ? base64decode(data.google_container_cluster.cluster[0].master_auth[0].cluster_ca_certificate) : null
  config_path = var.use_gke ? null : var.kubeconfig_path
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

# Reference existing namespaces created by kubectl apply (not managed by Terraform)
data "kubernetes_namespace_v1" "env" {
  for_each = var.environments

  metadata {
    name = each.value
  }
}

data "kubernetes_secret_v1" "dockerhub_pull_secret" {
  for_each = var.environments

  metadata {
    name      = "dockerhub-pull-secret"
    namespace = data.kubernetes_namespace_v1.env[each.key].metadata[0].name
  }
}

data "kubernetes_secret_v1" "qr_secret" {
  for_each = var.environments

  metadata {
    name      = "qr-secret"
    namespace = data.kubernetes_namespace_v1.env[each.key].metadata[0].name
  }
}
