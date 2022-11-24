terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "kms_arn" {
  type = string
}
variable "role" {
  type = string
}

data "aws_iam_policy_document" "kms-decrypt-tr" {
  count       = 1
  statement {
    sid       = "kmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_arn]
  }
}

resource "aws_iam_policy" "kms-policy" {
  name        = "kms-policy-test-1"
  policy      = data.aws_iam_policy_document.kms-decrypt-tr[0].json
}
resource "aws_iam_policy_attachment" "test-attachment" {
  name        = "test-attachment"
  roles       = [var.role]
  policy_arn  = aws_iam_policy.kms-policy.arn
}