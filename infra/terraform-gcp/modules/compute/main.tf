locals {
  startup_profiles = {
    jenkins = <<-EOT
      #!/usr/bin/env bash
      set -euxo pipefail
      apt-get update
      apt-get install -y ca-certificates curl gnupg lsb-release git apt-transport-https software-properties-common

      install -m 0755 -d /etc/apt/keyrings

      # Docker
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list

      # kubectl
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

      # Jenkins
      curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
      echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list

      # gcloud CLI
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg
      chmod 644 /etc/apt/keyrings/cloud.google.gpg
      echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list

      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin kubectl openjdk-17-jre jenkins google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin

      usermod -aG docker ${var.ssh_user}
      usermod -aG docker jenkins

      systemctl enable docker
      systemctl start docker
      systemctl enable jenkins
      systemctl start jenkins

      # Store initial password in motd for easy retrieval
      echo "Jenkins initial password:" > /etc/motd
      if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        cat /var/lib/jenkins/secrets/initialAdminPassword >> /etc/motd
      fi
    EOT

    runner = <<-EOT
      #!/usr/bin/env bash
      set -euxo pipefail
      apt-get update
      apt-get install -y ca-certificates curl gnupg lsb-release git apt-transport-https

      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list

      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin kubectl

      usermod -aG docker ${var.ssh_user}
      systemctl enable docker
      systemctl start docker
    EOT
  }
}

resource "google_compute_address" "vm_ip" {
  for_each = var.machines

  name   = "${var.name_prefix}-${each.key}-ip"
  region = var.region
}

resource "google_compute_instance" "vm" {
  for_each = var.machines

  name         = "${var.name_prefix}-${each.key}"
  machine_type = each.value.machine_type
  zone         = var.zone
  tags         = each.value.tags

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = each.value.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_id

    access_config {
      nat_ip = google_compute_address.vm_ip[each.key].address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  # Attach the Jenkins service account when it is a jenkins VM and an email
  # was provided. This grants gcloud / kubectl access to GKE without storing keys.
  dynamic "service_account" {
    for_each = (each.value.startup_profile == "jenkins" && var.jenkins_service_account_email != "") ? [1] : []
    content {
      email  = var.jenkins_service_account_email
      scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  }

  metadata_startup_script = lookup(local.startup_profiles, each.value.startup_profile, local.startup_profiles["runner"])
}
