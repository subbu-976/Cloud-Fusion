# cloudathon/provider.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Provider for asia-south2 region (active)
provider "google" {
  alias   = "asia-south2"
  project = "cloudathon-453114"
  region  = "asia-south2"
}

# Provider for asia-south1 region (passive)
provider "google" {
  alias   = "asia-south1"
  project = "cloudathon-453114"
  region  = "asia-south1"
}