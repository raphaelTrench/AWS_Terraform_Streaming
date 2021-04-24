terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.37.0"
    }
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = "${var.region}"
}

