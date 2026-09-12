data "archive_file" "trigger" {
  type        = "zip"
  source_file = "${path.module}/../lambda/trigger/handler.py"
  output_path = "${path.module}/../lambda/trigger/build.zip"
}

resource "aws_lambda_function" "trigger" {
  function_name    = "caughtu-trigger"
  filename         = data.archive_file.trigger.output_path
  source_code_hash = data.archive_file.trigger.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.trigger_lambda.arn
  timeout          = 30

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.media.bucket
      INSTANCE_ID = aws_instance.inference.id
    }
  }
}

data "archive_file" "report" {
  type        = "zip"
  source_file = "${path.module}/../lambda/report/handler.py"
  output_path = "${path.module}/../lambda/report/build.zip"
}

resource "aws_lambda_function" "report" {
  function_name    = "caughtu-report"
  filename         = data.archive_file.report.output_path
  source_code_hash = data.archive_file.report.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.report_lambda.arn
  timeout          = 30

  environment {
    variables = {
      BUCKET_NAME     = aws_s3_bucket.media.bucket
      TABLE_NAME      = aws_dynamodb_table.detections.name
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.recipient_email
    }
  }
}
