# Specify the provider and access details

provider "aws" {
  region     = "${var.aws_region}"
  profile    = "adfs"
  shared_credentials_file = "~/.aws/credentials"
}