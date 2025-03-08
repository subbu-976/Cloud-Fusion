# cloudathon/provider.tf

# Define required providers and their versions
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0" # Use a recent version; adjust as needed
    }
  }
}

# Configure the Google provider
provider "google" {
  project = "cloudathon-453114" # Replace with your GCP project ID
  region  = "asia-south2-a"     # Replace with your desired region
  # Credentials will be picked up from GOOGLE_CREDENTIALS env var in GitHub Actions
}