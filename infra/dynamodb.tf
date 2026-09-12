resource "aws_dynamodb_table" "detections" {
  name         = "caughtu-detections"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "camera_id"
  range_key    = "detection_ts"

  attribute {
    name = "camera_id"
    type = "S"
  }

  attribute {
    name = "detection_ts"
    type = "S"
  }

  attribute {
    name = "report_bucket"
    type = "S"
  }

  global_secondary_index {
    name            = "report_gsi"
    hash_key        = "report_bucket"
    range_key       = "detection_ts"
    projection_type = "ALL"
  }
}
