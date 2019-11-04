/* 
 * Create an API Gateway with integrations to SQS to act as PPS Builder API
 */
resource "aws_api_gateway_rest_api" "example" {
  name        = "API Skeleton - ${local.suffix}"
  description = "Skeleton for building an API on AWS with predefined roles and able to use a VPC."
  endpoint_configuration {
    types = ["PRIVATE"]
  }

  # set the policy to only allow access via VPC Endpoint
  policy = templatefile("${path.module}/policies/api_gateway.json.tmpl",
    {
        region=data.aws_region.current.name,
        account=data.aws_caller_identity.current.account_id,
        vpce=var.vpce
    })
}

/*
 * paths
 */

# /host
resource "aws_api_gateway_resource" "host" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  parent_id   = "${aws_api_gateway_rest_api.example.root_resource_id}"
  path_part   = "host"
}

# /host/request
resource "aws_api_gateway_resource" "hostRequest" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  parent_id   = "${aws_api_gateway_resource.host.id}"
  path_part   = "request"
}

# /host/status
resource "aws_api_gateway_resource" "hostStatus" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  parent_id   = "${aws_api_gateway_resource.host.id}"
  path_part   = "status"
}

/*
 * POST /host/request
 */
resource "aws_api_gateway_model" "host_config_request_model" {
  // a model to validate body of POST to /host/request
  rest_api_id  = "${aws_api_gateway_rest_api.example.id}"
  name         = "hostConfigRequestModel"
  description  = "schema for requests to apply a playbook to a system"
  content_type = "application/json"
  schema = "${file("${path.module}/host/request/postModel.json")}"
}
resource "aws_api_gateway_request_validator" "host_config_request_validator" {
  // a body validator for POST to /host/request
  name                  = "hostConfigRequestValidator"
  rest_api_id           = "${aws_api_gateway_rest_api.example.id}"
  validate_request_body = true
}
resource "aws_api_gateway_method" "hostRequest" {
  rest_api_id          = "${aws_api_gateway_rest_api.example.id}"
  resource_id          = "${aws_api_gateway_resource.hostRequest.id}"
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.host_config_request_validator.id}"
  request_models       = { "application/json" = "hostConfigRequestModel" }
  depends_on = [
    "aws_api_gateway_model.host_config_request_model"
  ]
}
resource "aws_api_gateway_integration" "request_to_sqs" {
  // put POSTs to /host/request into an SQS queue

  // basic integration parameters
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.hostRequest.resource_id}"
  http_method = "${aws_api_gateway_method.hostRequest.http_method}"
  integration_http_method = "POST"
  type                    = "AWS"

  // predefine a queue to write to and a role to use
  uri         = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${local.sqs_queue_name}"
  credentials = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.apigw_role}"

  // how to integrate with SQS
  passthrough_behavior = "NEVER"
  request_parameters = { 
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  request_templates = {
    // this is the code that will run to translate the JSON to SQS primitives
    "application/json" = "${file("${path.module}/host/request/intReqMapAppJson")}"
  }
}

resource "aws_api_gateway_method_response" "response200" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.hostRequest.resource_id}"
  http_method = "${aws_api_gateway_method.hostRequest.http_method}"
  status_code = "200"
}
resource "aws_api_gateway_integration_response" "hostRequest" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.hostRequest.resource_id}"
  http_method = "${aws_api_gateway_method.hostRequest.http_method}"
  status_code = "${aws_api_gateway_method_response.response200.status_code}"
}

/*
 * GET /host/status
 */
resource "aws_api_gateway_request_validator" "host_status_validator" {
  name = "hostStatusValidator"
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  validate_request_body = false
  validate_request_parameters = true
}
resource "aws_api_gateway_method" "hostStatus" {
  rest_api_id          = "${aws_api_gateway_rest_api.example.id}"
  resource_id          = "${aws_api_gateway_resource.hostStatus.id}"
  http_method          = "GET"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.host_status_validator.id}"
  request_parameters = {
    "method.request.querystring.hosts" = true
  }
  depends_on = [
    aws_api_gateway_resource.hostStatus,
    "aws_api_gateway_model.host_config_request_model"
  ]
}
resource "aws_api_gateway_integration" "hostStatus" {
  // basic integration definition
  depends_on = [ aws_api_gateway_method.hostStatus ]
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.hostStatus.resource_id}"
  http_method = "${aws_api_gateway_method.hostStatus.http_method}"
  integration_http_method = "POST"
  type = "AWS"

  // integration details
  uri  = "arn:aws:apigateway:${data.aws_region.current.name}:dynamodb:action/BatchGetItem"
  request_templates = {
    // this is the code that will run to translate the JSON to SQS primitives
    "application/json" = templatefile("${path.module}/host/status/intReqMapAppJson.tmpl",
    {
        user=local.suffix
    })
  }
  credentials = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.apigw_role}"
}
resource "aws_api_gateway_method_response" "hostStatusResponse200" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.hostStatus.resource_id}"
  http_method = "${aws_api_gateway_method.hostStatus.http_method}"
  status_code = "200"
}
resource "aws_api_gateway_integration_response" "hostStatus" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.hostStatus.resource_id}"
  http_method = "${aws_api_gateway_method.hostStatus.http_method}"
  status_code = "${aws_api_gateway_method_response.hostStatusResponse200.status_code}"
  response_templates = {
    "application/json" = templatefile("${path.module}/host/status/intResMapAppJson.tmpl", {user=local.suffix})
  }
}

/*
 * make deployments, one at-a-time to avoid errors
 */
resource "aws_api_gateway_deployment" "dev" {
  # will not be implicitly updated
  depends_on = [
    aws_api_gateway_integration.hostStatus,
    aws_api_gateway_integration.request_to_sqs
  ]
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  variables = {
    deployed_at = "${timestamp()}"
  }
  stage_name = "dev"
}
resource "aws_api_gateway_deployment" "integration" {
  # will be implicitly updated
  depends_on = [
    aws_api_gateway_deployment.dev,
    aws_api_gateway_integration.hostStatus,
    aws_api_gateway_integration.request_to_sqs
  ]
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  variables = {
    deployed_at = "${timestamp()}"
  }
  stage_name = "integration"
}
resource "aws_api_gateway_deployment" "prod" {
  # will be implicitly updated
  depends_on = [
    aws_api_gateway_deployment.integration,
    aws_api_gateway_integration.hostStatus,
    aws_api_gateway_integration.request_to_sqs
  ]
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  stage_name = "prod"
}

