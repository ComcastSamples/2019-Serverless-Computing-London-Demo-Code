resource "aws_dynamodb_table" "status" {
    name = "mystatus-${local.suffix}"
    read_capacity  = 20
    write_capacity = 20
    hash_key = "host"

    attribute {
        name = "host"
        type = "S"
    }

  tags = local.tags
}

/*
 * insert some sample data
 */
resource "aws_dynamodb_table_item" "example1" {
  table_name = "${aws_dynamodb_table.status.name}"
  hash_key   = "${aws_dynamodb_table.status.hash_key}"
  item = <<ITEM
{ "host": {"S": "myhost1"}, "status": {"S": "SUCCESS"} }
ITEM
}

resource "aws_dynamodb_table_item" "example2" {
  table_name = "${aws_dynamodb_table.status.name}"
  hash_key   = "${aws_dynamodb_table.status.hash_key}"
  item = <<ITEM
{ "host": {"S": "myhost2"}, "status": {"S": "FAILED"} }
ITEM
}

