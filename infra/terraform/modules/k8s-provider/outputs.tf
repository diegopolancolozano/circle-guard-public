output "cluster_endpoint" {
  description = "Endpoint del cluster Kubernetes"
  value       = var.use_gke ? data.google_container_cluster.cluster[0].endpoint : "local:${var.kubeconfig_path}"
}
