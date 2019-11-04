variable "owner" {
  description = "a tag to apply to supporting resources"
  type = "string"
}

variable "environment" {
  description = "a tag to apply to supporting resources"
  type = "string"
  default = "development"
}

variable "app_version" {
  description = "Version/path to select when loading lambda code from S3"
  type = "string"
  default = "0.1.0"
}

variable "bucket" {
  description = "Source of lambda code"
  type = "string"
}

variable "vpce" {
  description = "allowed VPC endpoint for traffic to API GW"
  type = string
}

variable "apigw_role" {
  description = "pre-created role for apigw, with path"
  type = "string"
}

variable "lambda_role" {
  description = "pre-created role for lambda, with path"
  type = "string"
}

variable "sqs_queue_base_name" {
  description = "name of the queue to be used in this sample"
  type = "string"
}

variable "stage" {
  description = "stage for deployment"
  type = "string"
  default = "test"
}
