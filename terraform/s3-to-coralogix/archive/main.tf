terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.17.1"
    }
  }
}

# ====================================================================================================
#                                       variables
# ====================================================================================================

variable "privatekey" {
  description = "The 'send your data' API key from Coralogix account"
  sensitive   = true
}
variable "coralogix_region" {
  description = "Enter the Coralogix account region [in lower-case letters]: \n- us\n- singapore\n- ireland\n- india\n- stockholm"
}
variable "application_name" {
  description = "The application name for the log group in Coralogix"
  type        = string
}
variable "subsystemName" {
  description = "The sub-system name for the log group in Coralogix"
  type        = string
}
variable "S3BucketName" {
  description = "the S3 bucket used for logging"
  type = string
}

locals {
  endpoint_url = {
    "US" = {
      url = "https://api.coralogix.us/api/v1/logs"
    }
    "Singapore" = {
      url = "https://api.coralogixsg.com/api/v1/logs"
    }
    "Europe" = {
      url = "https://api.coralogix.com/api/v1/logs"
    }
    "India" = {
      url = "https://api.app.coralogix.in/api/v1/logs"
    }
    "Stockholm" = {
      url = "https://api.eu2.coralogix.com/api/v1/logs"
    }
  }
}

#data "aws_partition" "current" {}
#data "aws_region" "current" {}

# ====================================================================================================
#                                       Resources
# ====================================================================================================

resource "aws_serverlessapplicationrepository_cloudformation_stack" "lambda" {
  application_id            = "arn:aws:serverlessrepo:eu-central-1:597078901540:applications/Coralogix-S3"
  capabilities              = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]
  name                      = "lambda-function-test"
  parameters = {
    PrivateKey              = var.privatekey
    ApplicationName         = var.application_name
    SubsystemName           = var.subsystemName
    S3BucketName            = var.S3BucketName
  }
}
