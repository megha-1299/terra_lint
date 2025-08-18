provider "aws" {
  region = "us-east-1"   # change this to your preferred region
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name-1234554546765464"  # bucket name must be globally unique
  acl    = "private"

  tags = {
    Name        = "MyBucket"
    Environment = "Dev"
  }
}
