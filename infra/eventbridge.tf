# --- hourly: trigger Lambda (Sprint 3) --------------------------------------
resource "aws_iam_role" "scheduler_trigger" {
  name = "caughtu-scheduler-trigger"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_trigger" {
  name = "caughtu-scheduler-trigger-invoke"
  role = aws_iam_role.scheduler_trigger.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.trigger.arn
    }]
  })
}

resource "aws_scheduler_schedule" "trigger_hourly" {
  name                = "caughtu-trigger-hourly"
  schedule_expression = "rate(1 hour)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.trigger.arn
    role_arn = aws_iam_role.scheduler_trigger.arn
  }
}

resource "aws_lambda_permission" "allow_scheduler_trigger" {
  statement_id  = "AllowSchedulerInvokeTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.trigger_hourly.arn
}

# --- every 8h: report Lambda (Sprint 4) -------------------------------------
resource "aws_iam_role" "scheduler_report" {
  name = "caughtu-scheduler-report"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_report" {
  name = "caughtu-scheduler-report-invoke"
  role = aws_iam_role.scheduler_report.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.report.arn
    }]
  })
}

resource "aws_scheduler_schedule" "report_8h" {
  name                = "caughtu-report-8h"
  schedule_expression = "rate(8 hours)"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.report.arn
    role_arn = aws_iam_role.scheduler_report.arn
  }
}

resource "aws_lambda_permission" "allow_scheduler_report" {
  statement_id  = "AllowSchedulerInvokeReport"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.report_8h.arn
}
