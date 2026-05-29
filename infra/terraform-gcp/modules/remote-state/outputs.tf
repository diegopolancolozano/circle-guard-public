output "bucket_name" {
  description = "Nombre del bucket de estado"
  value       = google_storage_bucket.terraform_state.name
}

output "bucket_url" {
  description = "URL del bucket (para backend config)"
  value       = "gs://${google_storage_bucket.terraform_state.name}"
}
