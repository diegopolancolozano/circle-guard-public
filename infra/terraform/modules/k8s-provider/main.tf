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
  cluster_ca_certificate = var.use_gke ? base64decode(data.google_container_cluster.cluster[0].master_auth[0].cluster_ca_certificate) : null
  config_path = var.use_gke ? null : var.kubeconfig_path
}
