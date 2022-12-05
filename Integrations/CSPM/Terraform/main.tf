terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.17.1"
    }
  }
}

# ==========================================================
#                          Data
# ==========================================================
data "aws_region" "current" {}
data "aws_subnet" "subnet" {
  id = var.Subnet_ID
}

# ==========================================================
#                       resources
# ==========================================================
resource "aws_instance" "cspm-instance" {
  ami                           = lookup(var.ubuntu-amis-map, data.aws_region.current.name)
  instance_type                 = var.instanceType
  key_name                      = var.SSHKeyName
  iam_instance_profile          = aws_iam_instance_profile.CSPMInstanceProfile.id
  associate_public_ip_address   = var.public_instance
  subnet_id                     = var.Subnet_ID
  vpc_security_group_ids        = [aws_security_group.CSPMSecurityGroup.id]
  user_data                     = "#!/bin/bash\nsudo apt update\nsudo apt-get remove docker docker-engine docker.io containerd runc\nsudo apt-get install ca-certificates curl gnupg lsb-release\nsudo mkdir -p /etc/apt/keyrings\ncurl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg\necho \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null\nsudo apt update\nsudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y \nsudo usermod -aG docker ubuntu \nnewgrp docker \ncrontab -l | { cat; echo \"${var.cronjob} docker rm snowbit-cspm ; docker rmi coralogixrepo/snowbit-cspm:${var.CSPMVersion} ; docker run --name snowbit-cspm -d -e PYTHONUNBUFFERED=1 -e CLOUD_PROVIDER=aws -e AWS_DEFAULT_REGION=eu-west-1 -e CORALOGIX_ENDPOINT_HOST=${lookup(var.grpc-endpoints-map, var.GRPC_Endpoint)} -e APPLICATION_NAME=${var.applicationName} -e SUBSYSTEM_NAME=${var.subsystemName} -e TESTER_LIST=${var.TesterList} -e API_KEY=${var.PrivateKey} -e REGION_LIST=${var.RegionList} -e CORALOGIX_ALERT_API_KEY=${var.alertAPIkey} -e COMPANY_ID=${var.Company_ID} -v ~/.aws/credentials:/root/.aws/credentials coralogixrepo/snowbit-cspm:${var.CSPMVersion}\"; } | crontab - \nsudo docker pull coralogixrepo/snowbit-cspm:${var.CSPMVersion} \ndocker run --name snowbit-cspm -d -e PYTHONUNBUFFERED=1 -e CLOUD_PROVIDER='aws' -e AWS_DEFAULT_REGION='eu-west-1' -e CORALOGIX_ENDPOINT_HOST=${lookup(var.grpc-endpoints-map, var.GRPC_Endpoint)} -e APPLICATION_NAME=${var.applicationName} -e SUBSYSTEM_NAME=${var.subsystemName} -e TESTER_LIST=${var.TesterList} -e API_KEY=${var.PrivateKey} -e REGION_LIST=${var.RegionList} -e CORALOGIX_ALERT_API_KEY=${var.alertAPIkey} -e COMPANY_ID=${var.Company_ID} -v ~/.aws/credentials:/root/.aws/credentials coralogixrepo/snowbit-cspm:${var.CSPMVersion}"
  root_block_device {
    volume_type = var.DiskType
    encrypted = var.ebs_encryption
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  tags = merge(var.additional_tags,
    {
      Name                        = "Snowbit CSPM"
      Terraform-ID                = random_id.id.hex
    },
  )
}
resource "aws_security_group" "CSPMSecurityGroup" {
  name                          = "CSPM-Security-Group-${random_id.id.hex}"
  vpc_id                        = data.aws_subnet.subnet.vpc_id
  description                   = "A security group for Snowbit CSPM"
  tags = merge(var.additional_tags,
    {
      Terraform-ID                = random_id.id.hex
    }
  )
  ingress {
    description               = var.SSHIpAddress == "0.0.0.0/0" ?  "SSH to the world" : "SSH to user provided IP - ${var.SSHIpAddress}"
    cidr_blocks               = [var.SSHIpAddress]
    from_port                 = 22
    to_port                   = 22
    protocol                  = "tcp"
    ipv6_cidr_blocks          = []
    prefix_list_ids           = []
    security_groups           = []
    self                      = false
  }
  egress {
    from_port                   = 0
    to_port                     = 0
    protocol                    = "-1"
    cidr_blocks                 = ["0.0.0.0/0"]
    ipv6_cidr_blocks            = ["::/0"]
  }
}
resource "aws_iam_instance_profile" "CSPMInstanceProfile" {
  role = aws_iam_role.CSPMRole.name
  tags = merge(var.additional_tags,
    {
      Terraform-ID                = random_id.id.hex
    }
  )
}
resource "aws_iam_role" "CSPMRole" {
  name                          = "CSPM-Role-${random_id.id.hex}"
  managed_policy_arns = [aws_iam_policy.CSPMPolicy.arn]
  tags = merge(var.additional_tags,
    {
      Terraform-ID                = random_id.id.hex
    }
  )
  assume_role_policy            = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_policy" "CSPMPolicy" {
  name = "CSPM-Policy-${random_id.id.hex}"
  policy                        = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        "Sid" : "CSPM",
        "Effect" : "Allow",
        "Action" : [
          "access-analyzer:Get*",
          "access-analyzer:List*",
          "acm:Describe*",
          "apigateway:Get*",
          "application-autoscaling:Describe*",
          "autoscaling-plans:Describe*",
          "autoscaling-plans:GetScalingPlanResourceForecastData",
          "autoscaling:Describe*",
          "autoscaling:GetPredictiveScalingForecast",
          "cloudformation:BatchDescribeTypeConfigurations",
          "cloudformation:Describe*",
          "cloudformation:DetectStack*",
          "cloudformation:EstimateTemplateCost",
          "cloudformation:Get*",
          "cloudformation:List*",
          "cloudformation:ValidateTemplate",
          "cloudfront:DescribeFunction",
          "cloudfront:Get*",
          "cloudfront:List*",
          "cloudtrail:Describe*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "cloudtrail:LookupEvents",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "codebuild:BatchGet*",
          "codebuild:Describe*",
          "codebuild:Get*",
          "codebuild:List*",
          "config:Describe*",
          "config:Get*",
          "config:List*",
          "dms:Describe*",
          "ec2:Describe*",
          "ec2:ExportClientVpn*",
          "ec2:Get*",
          "ec2:List*",
          "ec2:Search*",
          "ec2messages:Get*",
          "eks:Describe*",
          "eks:List*",
          "elasticache:Describe*",
          "elasticache:List*",
          "elasticloadbalancing:Describe*",
          "elasticmapreduce:Describe*",
          "elasticmapreduce:Get*",
          "elasticmapreduce:List*",
          "elasticmapreduce:ViewEventsFromAllClustersInConsole",
          "emr-containers:Describe*",
          "emr-containers:List*",
          "emr-serverless:Get*",
          "emr-serverless:List*",
          "es:Describe*",
          "es:Get*",
          "es:List*",
          "iam:Generate*",
          "iam:Get*",
          "iam:List*",
          "iam:Simulate*",
          "imagebuilder:Get*",
          "imagebuilder:List*",
          "kms:Describe*",
          "kms:Get*",
          "kms:List*",
          "lambda:Get*",
          "lambda:List*",
          "network-firewall:Describe*",
          "network-firewall:List*",
          "organizations:Describe*",
          "organizations:List*",
          "rds:Describe*",
          "redshift:Describe*",
          "redshift:List*",
          "redshift:ViewQueries*",
          "rolesanywhere:Get*",
          "rolesanywhere:list*",
          "route53:Get*",
          "route53:List*",
          "route53:TestDNSAnswer",
          "route53domains:CheckDomain*",
          "route53domains:Get*",
          "route53domains:List*",
          "route53domains:ViewBilling",
          "s3:Describe*",
          "s3:List*",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketPolicyStatus",
          "s3:GetEncryptionConfiguration",
          "s3:GetAccountPublicAccessBlock",
          "s3:GetBucketLogging",
          "s3:GetBucketVersioning",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetBucketPolicy",
          "servicequotas:Get*",
          "servicequotas:List*",
          "ses:Describe*",
          "ses:Get*",
          "ses:List*",
          "sns:Get*",
          "sns:List*",
          "sqs:Get*",
          "sqs:List*",
          "ssm:Describe*",
          "ssm:Get*",
          "ssm:List*",
          "sts:Get*",
          "tag:Get*",
          "waf-regional:Get*",
          "waf-regional:List*",
          "waf:Get*",
          "waf:List*",
          "wafv2:Describe*",
          "wafv2:Get*",
          "wafv2:List*"
        ],
        "Resource" : "*"
      }
    ]
  })
  tags = merge(var.additional_tags,
    {
      Terraform-ID                = random_id.id.hex
    }
  )
}
resource "random_id" "id" {
  byte_length = 4
}
