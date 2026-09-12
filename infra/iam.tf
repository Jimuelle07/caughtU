# --- local testing (Sprint 1) -----------------------------------------------
# Local-testing-only credentials (python run_batch.py from a dev machine
# against a real bucket/table before automation exists).
resource "aws_iam_user" "local_test" {
  name = "caughtu-local-test"
}

resource "aws_iam_user_policy" "local_test" {
  name = "caughtu-local-test-access"
  user = aws_iam_user.local_test.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.media.arn
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = [
          "${aws_s3_bucket.media.arn}/incoming/*",
          "${aws_s3_bucket.media.arn}/processed/*",
          "${aws_s3_bucket.media.arn}/crops/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.detections.arn
      }
    ]
  })
}

resource "aws_iam_access_key" "local_test" {
  user = aws_iam_user.local_test.name
}

output "local_test_access_key_id" {
  value = aws_iam_access_key.local_test.id
}

output "local_test_secret_access_key" {
  value     = aws_iam_access_key.local_test.secret
  sensitive = true
}

# --- EC2 inference instance (Sprint 2) --------------------------------------
resource "aws_iam_role" "ec2_inference" {
  name = "caughtu-ec2-inference"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_inference" {
  name = "caughtu-ec2-inference-access"
  role = aws_iam_role.ec2_inference.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.media.arn
        Condition = {
          StringLike = { "s3:prefix" = ["incoming/*", "processed/*", "code/*", "models/*"] }
        }
      },
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = [
          "${aws_s3_bucket.media.arn}/incoming/*",
          "${aws_s3_bucket.media.arn}/models/*",
          "${aws_s3_bucket.media.arn}/code/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "s3:DeleteObject"
        Resource = "${aws_s3_bucket.media.arn}/incoming/*"
      },
      {
        Effect = "Allow"
        Action = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.media.arn}/processed/*",
          "${aws_s3_bucket.media.arn}/crops/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:BatchWriteItem"]
        Resource = aws_dynamodb_table.detections.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "inference" {
  name = "caughtu-ec2-inference"
  role = aws_iam_role.ec2_inference.name
}

# --- trigger Lambda (Sprint 3) ----------------------------------------------
resource "aws_iam_role" "trigger_lambda" {
  name = "caughtu-trigger-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "trigger_lambda" {
  name = "caughtu-trigger-lambda-access"
  role = aws_iam_role.trigger_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.media.arn
        Condition = {
          StringLike = { "s3:prefix" = ["incoming/*", "processed/*"] }
        }
      },
      {
        Effect   = "Allow"
        Action   = "ec2:StartInstances"
        Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.inference.id}"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# --- report Lambda (Sprint 4) ------------------------------------------------
resource "aws_iam_role" "report_lambda" {
  name = "caughtu-report-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "report_lambda" {
  name = "caughtu-report-lambda-access"
  role = aws_iam_role.report_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "dynamodb:Query"
        Resource = [
          aws_dynamodb_table.detections.arn,
          "${aws_dynamodb_table.detections.arn}/index/report_gsi",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.media.arn}/reports/*"
      },
      {
        Effect   = "Allow"
        Action   = "ses:SendRawEmail"
        Resource = aws_ses_email_identity.sender.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}
