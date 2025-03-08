// Terraform data test block

data "google_compute_instance" "testserver" {
  name = "instance-20250308-140920"
  zone = "asia-south2-a"
}