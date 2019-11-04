locals {
    tags = {
        environment = "${var.environment}"
        owner = "${var.owner}"
    }

    # a suffix to use with AWS objects to distinguish them as development related.
    suffix = "${var.owner}"

    # queues don't allow suffixes and this name is used in many places
    sqs_queue_name = "${var.owner}-${var.sqs_queue_base_name}"

    # might be better to put all resource names here
}
