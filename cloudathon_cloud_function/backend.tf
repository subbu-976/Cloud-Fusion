terraform {
  backend "gcs" {
    bucket = "cloudathon-vdc"
    prefix = "terraform3/state"
  }
}
