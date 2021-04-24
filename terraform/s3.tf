resource "aws_s3_bucket" "raw_bucket" {

  bucket = "raw-beer-bucket-ml"
  acl    = "private"
  force_destroy = true
}

resource "aws_s3_bucket" "clean_bucket" {

  bucket = "cleaned-beer-bucket-ml"
  acl    = "private"
  force_destroy = true
}