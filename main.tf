# ---------------------------------------------------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 1)
}

# ---------------------------------------------------------------------------------------------------------------------
# Existing VPC Data Sources
# ---------------------------------------------------------------------------------------------------------------------
data "aws_vpc" "existing" {
  id = var.vpc_id
}

locals {
  subnet_id = var.subnet_ids[0]
}

# ---------------------------------------------------------------------------------------------------------------------
# KMS Keys
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "imagebuilder_image_recipe_kms_key" {
  description         = "Imagebuilder Image Recipe KMS key for ${var.name}"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "default"
    Statement = concat([
      {
        Sid    = "DefaultAllow"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowImageBuilderAccess"
        Effect = "Allow"
        Principal = {
          Service = "imagebuilder.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
      ], length(var.target_account_ids) > 0 ? [{
        Sid    = "Allow target accounts to use the key"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.target_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
    }] : [])
  })

  tags = var.tags
}

resource "aws_kms_alias" "imagebuilder_kms_alias" {
  name          = "alias/${var.name}-imagebuilder-key"
  target_key_id = aws_kms_key.imagebuilder_image_recipe_kms_key.key_id
}

resource "aws_kms_key" "s3_components_kms_key" {
  description         = "S3 Components Bucket KMS key for ${var.name}"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "default"
    Statement = [
      {
        Sid    = "DefaultAllow"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3Access"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Key Pair
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "imagebuilder" {
  algorithm = "RSA"
}

resource "aws_key_pair" "imagebuilder" {
  key_name   = "${var.name}-key-pair"
  public_key = tls_private_key.imagebuilder.public_key_openssh

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# Custom IAM Policy
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "custom_policy" {
  name        = "${var.name}-custom-policy"
  path        = "/"
  description = "Custom policy for ${var.name} Image Builder"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.components_bucket.arn
        ]
      },
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.components_bucket.arn}/*"
        ]
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.imagebuilder_image_recipe_kms_key.arn,
          aws_kms_key.s3_components_kms_key.arn
        ]
      }
    ]
  })

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# KMS Event Monitoring
# ---------------------------------------------------------------------------------------------------------------------

# CloudWatch Log Group for KMS events
resource "aws_cloudwatch_log_group" "kms_events" {
  name              = "/aws/kms/${var.name}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# EventBridge rule to capture KMS events
resource "aws_cloudwatch_event_rule" "kms_events" {
  name = "${var.name}-kms-events"
  event_pattern = jsonencode({
    source = ["aws.kms"]
    detail = {
      keyId = [
        aws_kms_key.imagebuilder_image_recipe_kms_key.id,
        aws_kms_key.s3_components_kms_key.id
      ]
    }
  })
  
  tags = var.tags
}

# EventBridge target to send events to CloudWatch Logs
resource "aws_cloudwatch_event_target" "logs" {
  rule      = aws_cloudwatch_event_rule.kms_events.name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.kms_events.arn
}



# ---------------------------------------------------------------------------------------------------------------------
# S3 Bucket for Components
# ---------------------------------------------------------------------------------------------------------------------
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "components_bucket" {
  bucket        = "image-components-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.components_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "components_bucket_encryption" {
  bucket = aws_s3_bucket.components_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_components_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Enforce HTTPS-only access to S3 bucket
resource "aws_s3_bucket_policy" "enforce_https" {
  bucket = aws_s3_bucket.components_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.components_bucket.arn,
          "${aws_s3_bucket.components_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "components_bucket_lifecycle" {
  bucket = aws_s3_bucket.components_bucket.id

  rule {
    id     = "components_cleanup"
    status = "Enabled"

    # Delete build logs older than configured days (must be > transition days)
    expiration {
      days = max(var.components_retention_days, 90)
    }

    # Clean up incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    # Delete non-current versions after 7 days (for versioned objects)
    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    # Transition older objects to cheaper storage classes
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }
  }

  # Separate rule for scripts - keep longer for debugging
  rule {
    id     = "scripts_retention"
    status = "Enabled"

    filter {
      prefix = "scripts/"
    }

    expiration {
      days = var.scripts_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}




