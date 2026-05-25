provider "google" {
  project = var.project_id
  region  = var.region
}

module "remote_state" {
  source      = "../modules/remote-state"
  bucket_name = var.state_bucket_name
  location    = var.state_bucket_location
  admin_member = "serviceAccount:${var.project_id}@cloudservices.gserviceaccount.com"
}
