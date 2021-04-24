variable "region" {
  description = "The AWS region we want this bucket to live in."
  default     = "us-east-1"
}

variable "storage_input_format" {
  description = "storage input format for aws glue for parcing data"
  default     = ""
}

variable "storage_output_format" {
  description = "storage output format for aws glue for parcing data"
  default     = ""
}

variable "requests_lambda_layer" {
  description = "python lambda layer"
  default     = "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-python38-requests:16"
}
	