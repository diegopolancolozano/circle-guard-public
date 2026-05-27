# ---------------------------------------------------------------------------
# Kubernetes provider: when use_gke=true, authenticates directly via GKE
# data source (uses GOOGLE_APPLICATION_CREDENTIALS or ADC). Otherwise loads
# a local kubeconfig (useful for DigitalOcean / local clusters).
# ---------------------------------------------------------------------------
data "google_client_config" "current" {}

data "google_container_cluster" "cluster" {
  count    = var.use_gke ? 1 : 0
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = var.gcp_project
}

provider "kubernetes" {
  host = var.use_gke ? "https://${data.google_container_cluster.cluster[0].endpoint}" : null
  token = var.use_gke ? data.google_client_config.current.access_token : null
  cluster_ca_certificate = var.use_gke ? base64decode(
    data.google_container_cluster.cluster[0].master_auth[0].cluster_ca_certificate
  ) : null
  config_path = var.use_gke ? null : var.kubeconfig_path
}

# ---------------------------------------------------------------------------
# Namespaces — created here so subsequent resources can reference them safely.
# kubectl apply already creates them via kustomize; using
# lifecycle.ignore_changes prevents Terraform from fighting over labels.
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "env" {
  for_each = var.environments

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "circleguard/environment"      = each.value
    }
  }

  lifecycle {
    # Namespace may already exist (created by kubectl apply); don't error out.
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

# ---------------------------------------------------------------------------
# Docker Hub pull secret — one per namespace
# ---------------------------------------------------------------------------
module "docker_secret" {
  source = "./modules/docker-secret"

  namespaces         = var.environments
  dockerhub_username = var.dockerhub_username
  dockerhub_password = var.dockerhub_password
  dockerhub_email    = var.dockerhub_email
  dockerhub_server   = var.dockerhub_server

  depends_on = [kubernetes_namespace_v1.env]
}

# ---------------------------------------------------------------------------
# QR / Gateway shared secret — one per namespace
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "qr_secret" {
  for_each = var.environments

  metadata {
    name      = "qr-secret"
    namespace = each.value
  }

  data = {
    QR_SECRET = var.qr_secret
  }

  depends_on = [kubernetes_namespace_v1.env]
}
