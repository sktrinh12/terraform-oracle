provider "aws" {
  region = var.awsprops.region
  shared_credentials_files = ["$HOME/.aws/credentials"]
  profile = "default"
}
