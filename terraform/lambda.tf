data "archive_file" "lambda_function_code_package" {
  type        = "zip"
  source_file = "../beer-service/handler.py"
  output_path = "../beer-service/handler.py.zip"
}

data "archive_file" "lambda_layer_package" {
  type        = "zip"
  source_dir = "../beer-service/lambda_layer/layer"
  output_path = "../beer-service/lambda_layer/lambda_layer.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = data.archive_file.lambda_layer_package.output_path
  layer_name = "basic_python_layer"

  compatible_runtimes = ["python3.8"]
  source_code_hash = filebase64sha256(data.archive_file.lambda_layer_package.output_path)
}

resource "aws_lambda_function" "lambda_beer_ingestor" {
  filename      = data.archive_file.lambda_function_code_package.output_path
  function_name = "get_raw_beers"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "handler.get_raw_beers"

  source_code_hash = filebase64sha256(data.archive_file.lambda_function_code_package.output_path)

  runtime = "python3.8"

  layers = [ aws_lambda_layer_version.lambda_layer.arn ]

  environment {
    variables = {
      KINESIS_STREAM_NAME = "${aws_kinesis_stream.beer_stream.name}"
    }
  }
}

resource "aws_lambda_function" "lambda_beer_processor" {
  filename      = aws_lambda_function.lambda_beer_ingestor.filename
  function_name = "clean_and_save_beers"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "handler.clean_and_save_beers"

  source_code_hash = filebase64sha256(aws_lambda_function.lambda_beer_ingestor.filename)

  layers = [ aws_lambda_layer_version.lambda_layer.arn ]

  runtime = "python3.8"

  timeout = 60
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-policy"
  role = aws_iam_role.iam_for_lambda.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Action": [
            "firehose:*"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:firehose:${var.region}:${data.aws_caller_identity.current.account_id}:deliverystream/${aws_kinesis_firehose_delivery_stream.cleaned_beer_stream.name}"
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
      },
      {
          "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:logs:*:*:*"
      }
]
}
EOF
}