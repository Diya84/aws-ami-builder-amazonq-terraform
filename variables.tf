variable "name" {
  description = "Name prefix for resources"
  type        = string
  default     = "ami-builder"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-_\\.\\(\\) ]+$", var.name))
    error_message = "Name can only contain alphanumeric characters, hyphens, underscores, periods, parentheses, and spaces."
  }
}
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
variable "vpc_id" {
  description = "ID of existing VPC to use"
  type        = string
}
variable "subnet_ids" {
  description = "List of subnet IDs to use (will use first available)"
  type        = list(string)
}
variable "vpc_cidr" {
  description = "CIDR block for VPC (only used when creating new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}
variable "instance_types" {
  description = "EC2 instance types for Image Builder"
  type        = list(string)
  default     = ["c5.large"]
  
  validation {
    condition = alltrue([
      for instance_type in var.instance_types :
      contains(["t3.medium", "t3.large", "c5.large", "c5.xlarge", "m5.large", "m5.xlarge"], instance_type)
    ])
    error_message = "Only approved instance types allowed: t3.medium, t3.large, c5.large, c5.xlarge, m5.large, m5.xlarge"
  }
}
variable "source_ami_name" {
  description = "Source AMI name pattern"
  type        = string
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}
variable "ami_name" {
  description = "Name for the created AMI"
  type        = string
  default     = "Custom AMI"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-_\\.\\(\\) ]+$", var.ami_name)) && length(var.ami_name) <= 128
    error_message = "AMI name can only contain alphanumeric characters, hyphens, underscores, periods, parentheses, and spaces. Max 128 characters."
  }
}

variable "ami_description" {
  description = "Description for the created AMI"
  type        = string
  default     = "Custom AMI built with EC2 Image Builder"
  
  validation {
    condition     = length(var.ami_description) <= 255 && !can(regex("[;<>&|$`]", var.ami_description))
    error_message = "Description must be under 255 characters and cannot contain command injection characters: ; < > & | $ `"
  }
}
variable "recipe_version" {
  description = "Image recipe version"
  type        = string
  default     = "0.0.1"
}
variable "build_version" {
  description = "Build component version"
  type        = string
  default     = "0.0.1"
}
variable "test_version" {
  description = "Test component version"
  type        = string
  default     = "0.0.1"
}
variable "build_file_name" {
  description = "Build component YAML file name"
  type        = string
  default     = "build-components.yaml"
}
variable "test_file_name" {
  description = "Test component YAML file name"
  type        = string
  default     = "test-components.yaml"
}
variable "component_name" {
  description = "Name of the component to use"
  type        = string
  default     = "custom-app"
}
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    created-by         = "Terraform"
    dataclassification = "internal"
    owner              = "Organization"
    environment        = "dev"
    project            = "ami-builder"
  }
}
variable "target_account_ids" {
  description = "List of AWS account IDs to share AMIs with"
  type        = list(string)
  default     = []
}
variable "ami_regions" {
  description = "List of regions to distribute AMIs to"
  type        = list(string)
  default     = ["us-west-2"]
  
  validation {
    condition     = length(var.ami_regions) <= 5
    error_message = "Maximum 5 regions allowed for AMI distribution to control costs."
  }
}

variable "enable_access_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 90
}

variable "components_retention_days" {
  description = "Number of days to retain build components and logs"
  type        = number
  default     = 30
  
  validation {
    condition     = var.components_retention_days >= 1 && var.components_retention_days <= 365
    error_message = "Components retention days must be between 1 and 365."
  }
}

variable "scripts_retention_days" {
  description = "Number of days to retain build scripts"
  type        = number
  default     = 90
  
  validation {
    condition     = var.scripts_retention_days >= 1 && var.scripts_retention_days <= 365
    error_message = "Scripts retention days must be between 1 and 365."
  }
}

variable "platform" {
  description = "OS: Windows or Linux"
  type        = string
  default     = "Windows"
  
  validation {
    condition     = contains(["Windows", "Linux"], var.platform)
    error_message = "Invalid input, options: \"Windows\", \"Linux\"."
  }
}