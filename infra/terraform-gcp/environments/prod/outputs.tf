output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "jenkins_url" {
  value = module.compute.jenkins_url
}

output "jenkins_service_account_email" {
  value = google_service_account.jenkins.email
}

output "get_credentials_command" {
  value = module.gke.get_credentials_command
}
