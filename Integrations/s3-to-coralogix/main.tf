terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17.1"
    }
  }
}
locals {
  coralogix_regions = {
    Europe    = "api.coralogix.com"
    Europe2   = "api.eu2.coralogix.com"
    India     = "api.app.coralogix.in"
    Singapore = "api.coralogixsg.com"
    US        = "api.coralogix.us"
  }
}
data "aws_region" "this" {}
data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms-decrypt" {
  count = 1
  statement {
    sid       = "kmsDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_arn]
  }
}
data "aws_iam_policy_document" "s3-bucket-access" {
  count = 1
  statement {
    sid     = "s3BucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
      "s3:GetLifecycleConfiguration"
    ]
    resources = ["arn:aws:s3:::${var.guardduty-s3-bucket}","arn:aws:s3:::${var.guardduty-s3-bucket}/*"]
  }
}
resource "aws_iam_policy" "kms-policy" {
  name   = "kms-policy-${random_string.this.result}"
  policy = data.aws_iam_policy_document.kms-decrypt[0].json
}
resource "aws_iam_policy" "s3-bucket-access" {
  name = "s3-bucket-access-${random_string.this.result}"
  policy = data.aws_iam_policy_document.s3-bucket-access[0].json
}
resource "aws_iam_policy_attachment" "kms-policy-attachment" {
  name       = "kms-policy"
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = aws_iam_policy.kms-policy.arn
}
resource "aws_iam_policy_attachment" "s3-policy-attachment" {
  name       = "s3-policy"
  roles      = [aws_iam_role.lambda-role.name]
  policy_arn = aws_iam_policy.s3-bucket-access.arn
}
resource "aws_iam_role" "lambda-role" {
  name               = "Lambda-Role-${random_string.this.result}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name   = "basicExecution"
    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          "Sid" : "basicExecution",
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:${data.aws_region.this}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.this.function_name}"
        }
      ]
    })
  }
}
resource "aws_lambda_function" "this" {
  function_name = "s3-to-coralogix"
  role          = aws_iam_role.lambda-role.arn
  s3_bucket     = "coralogix-serverless-repo-${data.aws_region.this.name}"
  s3_key        = "${var.package_name}.zip"
  runtime       = "nodejs16.x"
  handler       = "index.handler"
  architectures = [var.architecture]
  memory_size   = var.memory_size
  timeout       = var.timeout
  environment {
    variables = {
      CORALOGIX_URL         = "https://${lookup(local.coralogix_regions, var.coralogix_region, "Europe")}/api/v1/logs"
      CORALOGIX_BUFFER_SIZE = tostring(var.buffer_size)
      private_key           = var.private_key
      app_name              = var.application_name
      sub_name              = var.subsystem_name
      blocking_pattern      = var.blocking_pattern
      debug                 = var.debug
      newline_pattern       = var.newline_pattern
      sampling              = var.sampling_rate
    }
  }
}
resource "random_string" "this" {
  length  = 6
  special = false
}
resource "aws_lambda_permission" "invoke" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  statement_id = "invoke-${random_string.this.result}"
  source_arn = "arn:aws:s3:::${var.guardduty-s3-bucket}"
  source_account = data.aws_caller_identity.current.account_id
}
resource "aws_s3_bucket_notification" "this" {
  bucket = var.guardduty-s3-bucket
  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_key_prefix
    filter_suffix       = var.s3_key_suffix
  }
}