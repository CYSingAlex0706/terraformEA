resource "random_pet" "prefix" {}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = "asia-east2-a"
  credentials = file(var.credentials_path)
}

resource "google_compute_network" "tfnetwork" {
  name                    = "tf-vnet"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "snet" {
  for_each = var.subnets

  name          = each.value["name"]
  ip_cidr_range = element(each.value["address_prefixes"], 0)
  region        = "asia-east2"
  network       = google_compute_network.tfnetwork.self_link
}

resource "google_compute_firewall" "tf_nsg" {
  name    = "network-sg"
  network = google_compute_network.tfnetwork.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_instance" "tf_vm" {
  name         = "my-vm"
  machine_type = "n1-standard-1"
  zone         = "asia-east2-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    subnetwork = values(google_compute_subnetwork.snet)[0].self_link

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "azureuser:${tls_private_key.example_ssh.public_key_openssh}"
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/devstorage.full_control",
      "https://www.googleapis.com/auth/compute.readonly",
    ]
  }
}

module "lb" {
  source       = "GoogleCloudPlatform/lb/google"
  version      = "2.2.0"
  region       = var.region
  name         = "load-balancer"
  service_port = 80
  target_tags  = ["my-target-pool"]
  network      = google_compute_network.tfnetwork.name
}
