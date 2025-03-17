
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}


# Configure the Google Cloud provider for asia-south2 (primary region)
provider "google" {
  alias   = "asia-south2"
  project = "cloudathon-453114" # Replace with your GCP project ID
  region  = "asia-south2"
}

# Configure the Google Cloud provider for asia-south1 (replica region)
provider "google" {
  alias   = "asia-south1"
  project = "cloudathon-453114" # Replace with your GCP project ID
  region  = "asia-south1"
}

provider "kubernetes" {
  alias                  = "asia-south2"
  host                   = "https://${google_container_cluster.active_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.active_cluster.master_auth[0].cluster_ca_certificate)
}

# Kubernetes provider for asia-south1 (passive cluster)
provider "kubernetes" {
  alias                  = "asia-south1"
  host                   = "https://${google_container_cluster.passive_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.passive_cluster.master_auth[0].cluster_ca_certificate)
}