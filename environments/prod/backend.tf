terraform {
  backend "s3" {
    bucket       = "routebox-tfstate-prod"
    key          = "terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
