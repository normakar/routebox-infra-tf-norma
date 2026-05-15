terraform {
  backend "s3" {
    bucket       = "routebox-tfstate-dev-nr1"
    key          = "terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
