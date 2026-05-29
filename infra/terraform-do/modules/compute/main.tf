terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.42"
    }
  }
}

locals {
  # NOTA: el shebang DEBE estar en la columna 0 del string generado.
  # Usamos replace() para quitar la indentación que agrega el heredoc.
  startup_script = replace(
    <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release git apt-transport-https openjdk-21-jre

    install -m 0755 -d /etc/apt/keyrings

    # Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list

    # kubectl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin kubectl

    # doctl
    curl -sL "https://github.com/digitalocean/doctl/releases/download/v1.110.0/doctl-1.110.0-linux-amd64.tar.gz" | tar xz -C /usr/local/bin
    chmod +x /usr/local/bin/doctl

    systemctl enable docker && systemctl start docker

    # Jenkins via Docker (evita problemas de GPG del repo oficial)
    docker pull jenkins/jenkins:lts-jdk21
    docker run -d \
      --name jenkins \
      --restart always \
      -p 8080:8080 \
      -p 50000:50000 \
      -v jenkins_home:/var/jenkins_home \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /usr/local/bin/kubectl:/usr/local/bin/kubectl \
      -v /usr/local/bin/doctl:/usr/local/bin/doctl \
      jenkins/jenkins:lts-jdk21

    # motd con contraseña inicial
    cat > /etc/profile.d/jenkins-motd.sh << 'MOTD'
    PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
    if [ -n "$PASSWORD" ]; then
      echo "=== Jenkins initial admin password: $PASSWORD ==="
    fi
    MOTD
    chmod +x /etc/profile.d/jenkins-motd.sh
    EOT
    , "/^    /", ""  # quitar 4 espacios de indentación para que el shebang quede en col 0
  )
}

# ── Reserved public IP ───────────────────────────────────────────────────────
resource "digitalocean_reserved_ip" "jenkins" {
  region = var.region
}

# ── SSH key (optional — only created when ssh_public_key is provided) ────────
resource "digitalocean_ssh_key" "jenkins" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "${var.name_prefix}-jenkins-key"
  public_key = var.ssh_public_key
}

# ── Droplet ──────────────────────────────────────────────────────────────────
resource "digitalocean_droplet" "jenkins" {
  name      = "${var.name_prefix}-jenkins"
  region    = var.region
  size      = var.droplet_size
  image     = "ubuntu-22-04-x64"
  vpc_uuid  = var.vpc_uuid
  user_data = local.startup_script

  ssh_keys = var.ssh_public_key != "" ? [digitalocean_ssh_key.jenkins[0].fingerprint] : []

  tags = ["circleguard", "jenkins", var.environment]
}

# ── Assign reserved IP ───────────────────────────────────────────────────────
resource "digitalocean_reserved_ip_assignment" "jenkins" {
  ip_address = digitalocean_reserved_ip.jenkins.ip_address
  droplet_id = digitalocean_droplet.jenkins.id
}

# ── Firewall ─────────────────────────────────────────────────────────────────
resource "digitalocean_firewall" "jenkins" {
  name = "${var.name_prefix}-jenkins-fw"

  droplet_ids = [digitalocean_droplet.jenkins.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  # Jenkins UI
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Jenkins agent JNLP (optional — for distributed builds)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "50000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
