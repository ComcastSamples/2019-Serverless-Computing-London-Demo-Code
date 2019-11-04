/*
 * Lock down versions to create some operational stability.
 */
terraform {
  required_version = "~> 0.12"
}
provider "aws" {
  region = "us-west-2"
  version = "~> 2.30"
}
provider "template" {
  version = "~> 2.1"
}
