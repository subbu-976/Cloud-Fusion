// Terraform data test block

data "google_compute_instances" "all_instances_zone" {
  project = "cloudathon-453114"
  zone    = "asia-south2-a"
}