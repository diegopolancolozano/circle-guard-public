# ---------------------------------------------------------------------------
# GKE Standard cluster — circleguard
# ---------------------------------------------------------------------------
# Uses VPC-native networking (alias IP ranges) with the secondary ranges
# created by the vpc module.
# ---------------------------------------------------------------------------

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE node pool SA for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifactregistry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# ---------------------------------------------------------------------------
# GKE cluster — Standard mode (gives full kubectl access)
# ---------------------------------------------------------------------------
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Remove the default node pool immediately; we manage it ourselves below.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = var.subnet_name

  # VPC-native / alias IPs
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Workload Identity — lets K8s service accounts impersonate GCP SAs
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Disable basic auth / legacy ABAC
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Private cluster: nodes get private IPs; control plane accessible from
  # master_ipv4_cidr_block via private endpoint.
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  release_channel {
    channel = var.release_channel
  }

  # Logging / monitoring via Cloud Operations
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Delete protection off so Terraform can destroy in tests
  deletion_protection = var.deletion_protection
}

# ---------------------------------------------------------------------------
# Primary node pool
# ---------------------------------------------------------------------------
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-pool"
  cluster  = google_container_cluster.primary.id
  location = var.region
  project  = var.project_id

  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-balanced"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      env     = var.environment
      cluster = var.cluster_name
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
