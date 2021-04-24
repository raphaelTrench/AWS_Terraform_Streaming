resource "aws_kinesis_stream" "beer_stream" {
  name             = "beer-kinesis-ml"
  shard_count      = 1
  retention_period = 48

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]
}

resource "aws_kinesis_firehose_delivery_stream" "raw_beer_stream" {
  name        = "beer-raw-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
      kinesis_stream_arn = aws_kinesis_stream.beer_stream.arn
      role_arn = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.raw_bucket.arn
    buffer_size = 65
    buffer_interval = 60

    cloudwatch_logging_options {
      enabled = true
      log_group_name = aws_cloudwatch_log_group.beer_logs.name
      log_stream_name = aws_cloudwatch_log_stream.raw_beer_log_stream.name
    }
  }
}

resource "aws_kinesis_firehose_delivery_stream" "cleaned_beer_stream" {
  name        = "beer-clean-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
      kinesis_stream_arn = aws_kinesis_stream.beer_stream.arn
      role_arn = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.clean_bucket.arn
    buffer_size = 64

    cloudwatch_logging_options {
      enabled = true
      log_group_name = aws_cloudwatch_log_group.beer_logs.name
      log_stream_name = aws_cloudwatch_log_stream.clean_beer_log_stream.name
    }

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.lambda_beer_processor.arn}:$LATEST"
        }
      }
    }

  data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          hive_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = "${aws_glue_catalog_table.aws_glue_table.database_name}"
        role_arn      = "${aws_iam_role.firehose_role.arn}"
        table_name    = "${aws_glue_catalog_table.aws_glue_table.name}"
        region        = "${var.region}"
      }
    }
  }
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_beer_role"

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

resource "aws_iam_role_policy" "kinesis_policy" {
  name = "kinesis-policy"
  role = aws_iam_role.firehose_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "lambda:InvokeFunction",
              "lambda:GetFunctionConfiguration"
            ],
            "Resource": "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${aws_lambda_function.lambda_beer_processor.function_name}:$LATEST"
        },
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:DescribeStreamSummary",
                "kinesis:GetRecords",
                "kinesis:GetShardIterator",
                "kinesis:ListShards",
                "kinesis:ListStreams",
                "kinesis:PutRecords",
                "kinesis:PutRecord",
                "kinesis:SubscribeToShard"
            ],
            "Resource": [
                "arn:aws:kinesis:${var.region}:${data.aws_caller_identity.current.account_id}:stream/${aws_kinesis_stream.beer_stream.name}"
            ]
        },
        {
          "Effect": "Allow",
          "Action": [
              "s3:AbortMultipartUpload",
              "s3:GetBucketLocation",
              "s3:GetObject",
              "s3:ListBucket",
              "s3:ListBucketMultipartUploads",
              "s3:PutObject"
          ],
          "Resource": [
              "${aws_s3_bucket.raw_bucket.arn}",
              "${aws_s3_bucket.raw_bucket.arn}/*",
              "${aws_s3_bucket.clean_bucket.arn}",
              "${aws_s3_bucket.clean_bucket.arn}/*"
          ]
      },
      {
          "Effect": "Allow",
          "Action": [
              "glue:GetTable",
              "glue:GetTableVersion",
              "glue:GetTableVersions"
          ],
          "Resource": [
              "*"
          ]
      }
]
}
EOF
}