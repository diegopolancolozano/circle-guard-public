output "cluster_name" {
  description = "Nombre del cluster GKE"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS del API server de Kubernetes"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Certificado CA del cluster (base64)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_pool_name" {
  description = "Nombre del node pool principal"
  value       = google_container_node_pool.primary_nodes.name
}

output "node_service_account_email" {
  description = "Email de la service account usada por los nodos GKE"
  value       = google_service_account.gke_nodes.email
}

output "get_credentials_command" {
  description = "Comando para obtener credenciales del cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}
