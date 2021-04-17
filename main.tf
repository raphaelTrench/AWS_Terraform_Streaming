terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.37.0"
    }
  }
}

resource "aws_cloudwatch_event_rule" "lambda_trigger" {
  name        = "capture-aws-sign-in"

  event_pattern = <<EOF
{
  "detail-type": [
    "AWS Console Sign In via CloudTrail"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.console.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.aws_logins.arn
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_kinesis_stream" "beer_stream" {
  name             = "beer-kinesis-ml"
  shard_count      = 1
  retention_period = 48

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  name        = "beer-raw-stream"
  destination = "s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.raw_bucket.arn
  }

  kinesis_source_configuration = {
      kinesis_stream_arn = aws_kinesis_stream.beer_stream.arn
      role_arn: 
  }

}

resource "aws_s3_bucket" "raw_bucket" {

  bucket = "raw-beer-bucket-ml"
  acl    = "private"
}


resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  name        = "beer-clean-stream"

  kinesis_source_configuration = {
      kinesis_stream_arn = aws_kinesis_stream.beer_stream.arn
      role_arn: 
  }

}


resource "aws_s3_bucket" "clean-bucket" {

  bucket = "cleaned-beer-bucket-ml"
  acl    = "private"
}

