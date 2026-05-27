output "gke_cluster_name" {
  description = "Nombre del cluster GKE creado"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint HTTPS del cluster GKE"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "CA del cluster GKE (base64)"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "jenkins_url" {
  description = "URL de la consola Jenkins"
  value       = module.compute.jenkins_url
}

output "jenkins_vm_ip" {
  description = "IP publica del VM Jenkins"
  value       = try(module.compute.vm_public_ips["jenkins"], null)
}

output "jenkins_service_account_email" {
  description = "Email de la SA de Jenkins (para configurar en GKE RBAC si se necesita)"
  value       = google_service_account.jenkins.email
}

output "get_credentials_command" {
  description = "Comando gcloud para configurar kubectl localmente"
  value       = module.gke.get_credentials_command
}
