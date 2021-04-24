resource "aws_cloudwatch_event_rule" "every_five_minutes" {
  name                = "every-five-minutes"
  description         = "Fires every 5 minutes"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = "${aws_cloudwatch_event_rule.every_five_minutes.name}"
  target_id = "lambda"
  arn       = "${aws_lambda_function.lambda_beer_ingestor.arn}"
}

resource "aws_cloudwatch_log_group" "get_beer_lambda_log" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_beer_ingestor.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "beer_logs" {
  name = "beer_logs"
}

resource "aws_cloudwatch_log_stream" "raw_beer_log_stream" {
  name           = "raw_beer_log_stream"
  log_group_name = aws_cloudwatch_log_group.beer_logs.name
}

resource "aws_cloudwatch_log_stream" "clean_beer_log_stream" {
  name           = "clean_beer_log_stream"
  log_group_name = aws_cloudwatch_log_group.beer_logs.name
}

resource "aws_cloudwatch_log_group" "clean_beer_lambda_log" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_beer_processor.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_beer_ingestor.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every_five_minutes.arn}"
}