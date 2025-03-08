terraform {
  backend "gcs" {
    bucket = "cloudathon-vdc"
    prefix = "terraform/state"
  }
}
