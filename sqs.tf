/*
 * A queue to store job requests that will take a long time to complete.
 */
resource "aws_sqs_queue" "example_queue" {
  name                        = local.sqs_queue_name
  fifo_queue                  = true
  content_based_deduplication = true

  /* 
   * create a resource-based permission to allow the API to put messages
   * and the lambda process to remove them.
   */
  policy = templatefile("${path.module}/policies/sqs_queue.json.tmpl", {
    region="${data.aws_region.current.name}",
    account = "${data.aws_caller_identity.current.account_id}",
    apigw_role="${var.apigw_role}",
    lambda_role="${var.lambda_role}",
    sqs_queue=local.sqs_queue_name
  })
  tags = local.tags
}
