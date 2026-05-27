terraform {
  backend "gcs" {
    bucket = "circleguard-tfstate"
    prefix = "terraform-k8s/dev"
  }
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
}

data "google_client_config" "current" {}

data "google_container_cluster" "cluster" {
  count    = var.use_gke ? 1 : 0
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = var.gcp_project
}

provider "google" {
  project = var.gcp_project
}

provider "kubernetes" {
  host = var.use_gke ? "https://${data.google_container_cluster.cluster[0].endpoint}" : null
  token = var.use_gke ? data.google_client_config.current.access_token : null
  cluster_ca_certificate = var.use_gke ? base64decode(
    data.google_container_cluster.cluster[0].master_auth[0].cluster_ca_certificate
  ) : null
  config_path = var.use_gke ? null : var.kubeconfig_path
}

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
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

module "docker_secret" {
  source = "../../modules/docker-secret"

  namespaces         = var.environments
  dockerhub_username = var.dockerhub_username
  dockerhub_password = var.dockerhub_password
  dockerhub_email    = var.dockerhub_email
  dockerhub_server   = var.dockerhub_server

  depends_on = [kubernetes_namespace_v1.env]
}

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
