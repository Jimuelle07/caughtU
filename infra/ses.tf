variable "sender_email" {
  description = "SES-verified sender identity; you must click the AWS verification email after apply"
  type        = string
}

variable "recipient_email" {
  type    = string
  default = "jimuellepatron10@gmail.com"
}

resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

resource "aws_ses_email_identity" "recipient" {
  email = var.recipient_email
}
