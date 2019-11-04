/* 
 * Process long running jobs, triggered by a Cloudwatch event (below)
 */
resource "aws_lambda_function" "example" {
  function_name = "processMessage-${local.suffix}"
  s3_bucket = "${var.bucket}"
  s3_key = "v${var.app_version}/processMessage.zip"
  handler = "processMessage.handler"
  runtime = "nodejs8.10"

  role = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lambda_role}"

  environment {
    variables = {
      queueUrl = "${aws_sqs_queue.example_queue.id}"
      table = "${aws_dynamodb_table.status.name}"
    }
  }
  tags = local.tags
}

/* 
 * enable our function to be called by the API for testing, it'll usually
 * be called by the Cloudwatch event below.
 */
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.example.arn}"
  principal     = "apigateway.amazonaws.com"

  # grant permission on the API instead of the deployment to enable testing
  # from the API Gateway AWS portal.
  source_arn = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"
}

/*
 * Run our function to process long running jobs on a regular basis.
 */
resource "aws_cloudwatch_event_rule" "builder_jobs" {
    name = "BuilderJobs"
    schedule_expression = "rate(1 minute)"
}
resource "aws_cloudwatch_event_target" "process_jobs" {
    rule = "${aws_cloudwatch_event_rule.builder_jobs.name}"
    arn = "${aws_lambda_function.example.arn}"
}
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.example.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.builder_jobs.arn}"
}
