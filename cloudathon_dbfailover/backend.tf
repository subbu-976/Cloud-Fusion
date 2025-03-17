terraform {
  backend "gcs" {
    bucket = "cloudathon-vdc"
    prefix = "terraformdb/state"
  }
}
