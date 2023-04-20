## gke Resources

data "terraform_remote_state" "gke" {
  backend = "local"
  config = {
    path = "../GCP/terraform.tfstate"
  }
}

provider "gcp" {
  region = "asia-east2"
}


data "gcp_gke_cluster" "cluster" {
  depends_on = [module.gke.cluster_id]
  name = "education-gke-EjLutf9m"
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

  experiments {
    manifest_resource = true
  }
}


provider "helm" {
  alias = "gke"
  kubernetes {
    host                   = data.gcp_gke_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.gcp_gke_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      args        = ["gke", "get-token", "--cluster-name", data.gcp_gke_cluster.cluster.name]
      command     = "gcp"
    }
  }
}
  
resource "helm_release" "consul_dc1" {
  provider   = helm.gke
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  version    = "0.32.1"

  values = [
    file("dc1.yaml")
  ]
}

data "kubernetes_secret" "gke_federation_secret" {
  provider = kubernetes.gke
  metadata {
    name = "consul-federation"
  }

  depends_on = [helm_release.consul_dc1]
}

## AKS Resources

data "terraform_remote_state" "aks" {
  backend = "local"
  config = {
    path = "../azure/terraform.tfstate"
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

  experiments {
    manifest_resource = true
  }
}

provider "helm" {
  alias = "aks"
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
  }
}

resource "kubernetes_secret" "aks_federation_secret" {
  provider = kubernetes.aks
  metadata {
    name = "consul-federation"
  }

  data = data.kubernetes_secret.gke_federation_secret.data
}


resource "helm_release" "consul_dc2" {
  provider   = helm.aks
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  version    = "0.32.1"

  values = [
    file("dc2.yaml")
  ]

  depends_on = [kubernetes_secret.aks_federation_secret]
}

