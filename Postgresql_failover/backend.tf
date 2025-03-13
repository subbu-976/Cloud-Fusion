terraform {
  backend "gcs" {
    bucket = "ltc-hack-prj-1-bucket"
    prefix = "terraform/state"
  }
}
