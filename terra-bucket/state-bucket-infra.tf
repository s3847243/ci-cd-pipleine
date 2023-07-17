terraform {
  required_providers {
    aws = {
    source = "hashicorp/aws"
    version = "~> 4.0"
    }
  }
  backend "local" {}
}

# region 
provider "aws" {
  region = "us-east-1"
}

# creating s3 bucket
resource "aws_s3_bucket" "state_bucket" {
  bucket = "s3-state-bucket-s3847243"

}

# enabling versioning for s3 bucket
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.state_bucket.id

   versioning_configuration {
    status = "Enabled"
  }
}

# Terraform state locking using DynamoDB
resource "aws_dynamodb_table" "state_bucket_lock" {
  name           = "state-lock"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}