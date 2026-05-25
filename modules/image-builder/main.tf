# ---------------------------------------------------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_ami" "source_ami" {
  most_recent = true
  owners      = [var.source_ami_owner]
  
  filter {
    name   = "name"
    values = [var.source_ami_name]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_imagebuilder_components" "managed_components" {
  for_each = {
    for index, mc in var.managed_components :
    mc.name => mc
  }
  owner = "Amazon"

  filter {
    name   = "platform"
    values = [var.platform]
  }

  filter {
    name   = "name"
    values = [each.value.name]
  }

  filter {
    name   = "version"
    values = [each.value.version]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Security Group
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "security_group" {
  count = var.create_security_group ? 1 : 0
  #checkov:skip=CKV2_AWS_5:Security Group is being attached if var create_security_group is true
  name        = "${var.name}-sg"
  description = "Security Group for for the EC2 Image Builder Build Instances"
  vpc_id      = data.aws_vpc.selected.id

  tags = var.tags
}

resource "aws_security_group_rule" "sg_https_ingress" {
  count             = var.create_security_group ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.security_group[count.index].id
  description       = "HTTPS from VPC"
}

resource "aws_security_group_rule" "sg_rdp_ingress" {
  count             = var.create_security_group && length(var.source_cidr) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = var.source_cidr
  security_group_id = aws_security_group.security_group[count.index].id
  description       = "RDP from the source variable CIDR"
}

#tfsec:ignore:aws-vpc-no-public-egress-sgr
resource "aws_security_group_rule" "sg_internet_egress" {
  count             = var.create_security_group ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group[count.index].id
  description       = "Access to the internet"
}


# ---------------------------------------------------------------------------------------------------------------------
# IAM Role
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "awsserviceroleforimagebuilder" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
  name               = "${var.name}-role"
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "imagebuilder" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  role       = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "EC2InstanceProfileImageBuilder-${var.name}"
  role = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_role_policy_attachment" "custom_policy" {
  count      = var.attach_custom_policy ? 1 : 0
  policy_arn = var.custom_policy_arn
  role       = aws_iam_role.awsserviceroleforimagebuilder.name
}

resource "aws_iam_role_policy" "aws_policy" {
  count  = length(var.target_account_ids) > 0 ? 1 : 0
  name   = "${var.name}-aws-access"
  role   = aws_iam_role.awsserviceroleforimagebuilder.id
  policy = data.aws_iam_policy_document.aws_policy.json
}

data "aws_iam_policy_document" "aws_policy" {

  # Only create cross-account policy when target accounts are specified
  dynamic "statement" {
    for_each = length(var.target_account_ids) > 0 ? [1] : []
    content {
      sid       = "CrossAccountRoleAssumption"
      effect    = "Allow"
      actions   = ["sts:AssumeRole"]
      resources = [
        for account_id in var.target_account_ids : 
        "arn:aws:iam::${account_id}:role/EC2ImageBuilderDistributionCrossAccountRole"
      ]
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Infrastructure Configuration
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_imagebuilder_infrastructure_configuration" "imagebuilder_infrastructure_configuration" {
  count                 = 1
  instance_profile_name = aws_iam_instance_profile.iam_instance_profile.name
  instance_types        = var.instance_types
  key_pair              = var.instance_key_pair

  name               = "${var.name}-infrastructure-configuration"
  security_group_ids = var.create_security_group ? [aws_security_group.security_group[count.index].id] : var.security_group_ids
  subnet_id          = var.subnet_id

  instance_metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  terminate_instance_on_failure = var.terminate_on_failure
  resource_tags                 = var.tags
  tags                          = var.tags

  logging {
    s3_logs {
      s3_bucket_name = var.s3_bucket_name
      s3_key_prefix  = "logs/${var.name}"
    }
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Image
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_imagebuilder_image" "imagebuilder_image" {
  count                            = 1
  image_recipe_arn                 = aws_imagebuilder_image_recipe.imagebuilder_image_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.imagebuilder_infrastructure_configuration[count.index].arn
  distribution_configuration_arn   = try(aws_imagebuilder_distribution_configuration.imagebuilder_distribution_configuration[count.index].arn, null)

  image_tests_configuration {
    image_tests_enabled = true
  }
  tags = var.tags

  timeouts {
    create = var.timeout
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Image Pipeline
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_imagebuilder_image_pipeline" "imagebuilder_image_pipeline" {
  count                            = 1
  image_recipe_arn                 = aws_imagebuilder_image_recipe.imagebuilder_image_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.imagebuilder_infrastructure_configuration[count.index].arn
  distribution_configuration_arn   = try(aws_imagebuilder_distribution_configuration.imagebuilder_distribution_configuration[count.index].arn, null)
  dynamic "schedule" {
    for_each = try(var.schedule_expression, [])
    content {
      schedule_expression                = schedule.value.scheduleExpression
      pipeline_execution_start_condition = schedule.value.pipeline_execution_start_condition
    }
  }
  name = "${var.name}-pipeline"
  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Image Recipe
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_imagebuilder_image_recipe" "imagebuilder_image_recipe" {
  name         = "${var.name}-image-recipe"
  parent_image = data.aws_ami.source_ami.id
  version      = var.recipe_version

  # it seems there is a bug on checkov for check CKV_AWS_200, even supressing it doesn't help, had to add the below block_device_mapping to pass
  block_device_mapping {
    device_name = "/dev/xvdb"

    ebs {
      delete_on_termination = true
      volume_size           = var.recipe_volume_size
      volume_type           = var.recipe_volume_type
      encrypted             = true
      kms_key_id            = var.imagebuilder_image_recipe_kms_key_arn
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  # Always include the build component
  component {
    component_arn = aws_imagebuilder_component.build_component.arn
    parameter {
      name  = "S3BucketName"
      value = var.s3_bucket_name
    }
  }

  # Always include the test component
  component {
    component_arn = aws_imagebuilder_component.test_component.arn
    parameter {
      name  = "S3BucketName"
      value = var.s3_bucket_name
    }
  }

  # Include any managed components if specified
  dynamic "component" {
    for_each = {
      for key, value in data.aws_imagebuilder_components.managed_components : key => value.arns
    }
    content {
      component_arn = tolist(component.value)[0]
    }
  }

  # Include any additional build components if specified
  dynamic "component" {
    for_each = var.build_component_arn
    content {
      component_arn = component.value
      parameter {
        name  = "S3BucketName"
        value = var.s3_bucket_name
      }
    }
  }

  # Include any additional test components if specified
  dynamic "component" {
    for_each = var.test_component_arn
    content {
      component_arn = component.value
      parameter {
        name  = "S3BucketName"
        value = var.s3_bucket_name
      }
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Distribution Configuration
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_imagebuilder_distribution_configuration" "imagebuilder_distribution_configuration" {
  count = length(var.target_account_ids) > 0 || length(var.ami_regions) > 1 ? 1 : 0
  name  = "${var.name}-distribution"

  dynamic "distribution" {
    for_each = toset(var.ami_regions)
    content {
      region = distribution.value
      ami_distribution_configuration {
        name               = "${var.ami_name}-{{ imagebuilder:buildDate }}"
        description        = var.ami_description
        target_account_ids = var.target_account_ids
        launch_permission {
          user_ids = var.target_account_ids
        }
        ami_tags = var.tags
        # Use custom KMS key for cross-account encryption
        kms_key_id = var.distribution_kms_key_arn
      }
    }
  }
  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 Objects for Components
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_object" "build_component" {
  bucket                 = var.s3_bucket_name
  key                    = "${var.name}/${var.build_file_name}"
  source                 = var.component_build_path
  server_side_encryption = "aws:kms"
  kms_key_id            = var.s3_components_kms_key_arn
  tags                   = var.tags
}

resource "aws_s3_object" "test_component" {
  bucket                 = var.s3_bucket_name
  key                    = "${var.name}/${var.test_file_name}"
  source                 = var.component_test_path
  server_side_encryption = "aws:kms"
  kms_key_id            = var.s3_components_kms_key_arn
  tags                   = var.tags
}

# Upload main scripts
resource "aws_s3_object" "upload_scripts" {
  for_each = fileset(var.scripts_path, var.platform == "Windows" ? "*.ps1" : "*.sh")

  bucket                 = var.s3_bucket_name
  key                    = "scripts/${var.name}/${each.value}"
  source                 = "${var.scripts_path}/${each.value}"
  server_side_encryption = "aws:kms"
  kms_key_id            = var.s3_components_kms_key_arn
  tags                   = var.tags
}

# Upload test scripts
resource "aws_s3_object" "upload_test_scripts" {
  for_each = fileset("${var.scripts_path}/tests", var.platform == "Windows" ? "*.ps1" : "*.sh")

  bucket                 = var.s3_bucket_name
  key                    = "scripts/${var.name}/tests/${each.value}"
  source                 = "${var.scripts_path}/tests/${each.value}"
  server_side_encryption = "aws:kms"
  kms_key_id            = var.s3_components_kms_key_arn
  tags                   = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 Access Logging Configuration
# ---------------------------------------------------------------------------------------------------------------------

# Generate random suffix for access logs bucket
resource "random_id" "access_logs_bucket_suffix" {
  count       = var.enable_access_logging ? 1 : 0
  byte_length = 8
}

# Dedicated bucket for access logs
resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV2_AWS_6:Public access block is configured in separate resource aws_s3_bucket_public_access_block.access_logs_pab
  count  = var.enable_access_logging ? 1 : 0
  bucket = "${var.name}-access-logs-${random_id.access_logs_bucket_suffix[0].hex}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "access_logs_versioning" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.imagebuilder_image_recipe_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs_pab" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM policy for S3 service to write access logs
resource "aws_s3_bucket_policy" "access_logs_policy" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_logs[0].arn}/access-logs/*"
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:s3:::${var.s3_bucket_name}"
          }
        }
      },
      {
        Sid    = "S3ServerAccessLogsDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.access_logs[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = "arn:aws:s3:::${var.s3_bucket_name}"
          }
        }
      }
    ]
  })
}

# Lifecycle policy for log management
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "access_logs_retention"
    status = "Enabled"

    filter {
      prefix = "access-logs/"
    }

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Configure access logging on the main S3 bucket
resource "aws_s3_bucket_logging" "main_bucket_logging" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = var.s3_bucket_name

  target_bucket = aws_s3_bucket.access_logs[0].id
  target_prefix = "access-logs/"

  depends_on = [
    aws_s3_bucket_policy.access_logs_policy
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# EC2 Image Builder Components
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_imagebuilder_component" "build_component" {
  name       = "${var.name}-build"
  version    = var.build_version
  platform   = var.platform
  uri        = "s3://${var.s3_bucket_name}/${var.name}/${var.build_file_name}"
  

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_s3_object.build_component
  ]
  tags = var.tags
}

resource "aws_imagebuilder_component" "test_component" {
  name       = "${var.name}-test"
  version    = var.test_version
  platform   = var.platform
  uri        = "s3://${var.s3_bucket_name}/${var.name}/${var.test_file_name}"
  

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_s3_object.test_component
  ]
  tags = var.tags
}