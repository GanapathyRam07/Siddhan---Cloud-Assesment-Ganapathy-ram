terraform {
  backend "s3" {
    bucket       = "cloud-assessment-tfstate"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}