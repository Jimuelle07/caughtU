terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_suffix" {
  description = "Appended to caughtu-media- to make the S3 bucket name globally unique"
  type        = string
}

output "bucket_name" {
  value = aws_s3_bucket.media.bucket
}

output "table_name" {
  value = aws_dynamodb_table.detections.name
}
