output "caller_arn" {
  description = "ARN of the user credential being used by terraform"
  value = "${data.aws_caller_identity.current.arn}"
}

output "API_ID" {
  description = "Use with 'x-apigw-api-id' header in HTTP requests"
  value = "${aws_api_gateway_rest_api.example.id}"
}

output "base_url" {
  description = "The base URL to use with HTTP, add the path"
  value = "${aws_api_gateway_deployment.dev.invoke_url}"
}
