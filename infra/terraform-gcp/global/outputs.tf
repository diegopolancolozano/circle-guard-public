output "state_bucket" {
  description = "Nombre del bucket para estado remoto"
  value       = module.remote_state.bucket_name
}

output "backend_config" {
  description = "Configuracion para backend remoto en environments/"
  value = {
    bucket = module.remote_state.bucket_name
    prefix = "terraform-gcp"
  }
}
