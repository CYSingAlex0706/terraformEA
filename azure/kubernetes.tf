/*
provider "kubernetes" {
  host                   = data.gcp_gke_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.gcp_gke_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "gcp"
    args = [
      "gke",
      "get-token",
      "--cluster-name",
      data.gcp_gke_cluster.cluster.name
    ]
  }
}
*/