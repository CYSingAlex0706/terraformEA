# ## AKS resources

data "terraform_remote_state" "aks" {
  backend = "local"
  config = {
    path = "../aks/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_kubernetes_cluster" "cluster" {
  name                = data.terraform_remote_state.aks.outputs.kubernetes_cluster_name
  resource_group_name = data.terraform_remote_state.aks.outputs.resource_group_name
}
provider "kubernetes" {
  alias                  = "aks"
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_pod" "counting" {
  provider = kubernetes.aks

  metadata {
    name = "counting"
    labels = {
      "app" = "counting"
    }
  }

  spec {
    container {
      image = "hashicorp/counting-service:0.0.2"
      name  = "counting"

      port {
        container_port = 9001
        name           = "http"
      }
    }
  }
}

resource "kubernetes_service" "counting" {
  provider = kubernetes.aks
  metadata {
    name      = "counting"
    namespace = "default"
    labels = {
      "app" = "counting"
    }
  }
  spec {
    selector = {
      "app" = "counting"
    }
    port {
      name        = "http"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# gke resources 

data "terraform_remote_state" "gke" {
  backend = "local"
  config = {
    path = "../gke/terraform.tfstate"
  }
}

provider "gcp" {
  region = data.terraform_remote_state.gke.outputs.region
}

data "gcp_gke_cluster" "cluster" {
  name = data.terraform_remote_state.gke.outputs.cluster_id
}

provider "kubernetes" {
  alias                  = "gke"
  host                   = data.gcp_gke_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.gcp_gke_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["gke", "get-token", "--cluster-name", data.gcp_gke_cluster.cluster.name]
    command     = "gcp"
  }
}

resource "kubernetes_pod" "dashboard" {
  provider = kubernetes.gke

  metadata {
    name = "dashboard"
    annotations = {
      "consul.hashicorp.com/connect-service-upstreams" = "counting:9001:dc2"
    }
    labels = {
      "app" = "dashboard"
    }
  }

  spec {
    container {
      image = "hashicorp/dashboard-service:0.0.4"
      name  = "dashboard"

      env {
        name  = "COUNTING_SERVICE_URL"
        value = "http://localhost:9001"
      }

      port {
        container_port = 9002
        name           = "http"
      }
    }
  }
}

resource "kubernetes_service" "dashboard" {
  provider = kubernetes.gke

  metadata {
    name      = "dashboard-service-load-balancer"
    namespace = "default"
    labels = {
      "app" = "dashboard"
    }
  }

  spec {
    selector = {
      "app" = "dashboard"
    }
    port {
      port        = 80
      target_port = 9002
    }

    type             = "LoadBalancer"
    load_balancer_ip = ""
  }
}
