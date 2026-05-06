output "managed_namespaces" {
  description = "Namespaces referenciados por Terraform"
  value       = sort([for ns in data.kubernetes_namespace_v1.env : ns.metadata[0].name])
}
