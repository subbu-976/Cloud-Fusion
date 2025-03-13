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