variable "project_id" {
  description = "project id"
}

variable "credentials_path" {
  type    = string
  default = "absolute-vertex-356001-d6e6c4ffa61f.json"
}

variable "region" {
  description = "region"
  default     = "asia-east2"
}

variable "zone" {
  type    = string
  default = "asia-east2-a"
}

variable "image" {
  type    = string
  default = "debian-cloud/debian-11"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

variable "subnets" {
  type = map(any)
  default = {
    subnet_1 = {
      name             = "subnet1"
      address_prefixes = ["10.0.1.0/24"]
    }
    subnet_2 = {
      name             = "subnet2"
      address_prefixes = ["10.0.2.0/24"]
    }
  }
}