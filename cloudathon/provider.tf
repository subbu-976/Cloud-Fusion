# cloudathon/provider.tf

# Define required providers and their versions
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.24.0"
    }
  }
}

# Configure the Google provider
provider "google" {
  project = "cloudathon-453114" # Replace with your GCP project ID
  region  = "asia-south2-a"     # Replace with your desired region
  # Credentials will be picked up from GOOGLE_CREDENTIALS env var in GitHub Actions
}