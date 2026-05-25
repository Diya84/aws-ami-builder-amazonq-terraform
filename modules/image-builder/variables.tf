variable "name" {
  description = "Name prefix for resources"
  type        = string
}
variable "aws_region" {
  description = "AWS region"
  type        = string
}
variable "vpc_id" {
  description = "VPC ID to deploy the EC2 Image Builder Environment"
  type        = string
}
variable "subnet_id" {
  description = "Subnet ID to deploy the EC2 Image Builder Environment"
  type        = string
}
variable "source_cidr" {
  description = "Source CIDR block which will be allowed to RDP or SSH to EC2 Image Builder Instances"
  type        = list(string)
  default     = []
}
variable "create_security_group" {
  description = "Create security group for EC2 Image Builder instances"
  type        = bool
  default     = true
}
variable "security_group_ids" {
  description = "Security group IDs for EC2 Image Builder instances"
  type        = list(string)
  default     = []
}
variable "instance_types" {
  description = "EC2 instance types for Image Builder"
  type        = list(string)
  default     = ["c5.large"]
}
variable "instance_key_pair" {
  description = "EC2 key pair to add to the default user on the builder"
  type        = string
  default     = null
}
variable "source_ami_name" {
  description = "Source AMI name pattern"
  type        = string
}
variable "source_ami_owner" {
  description = "Owner of the source AMI"
  type        = string
  default     = "amazon"
}

variable "s3_components_kms_key_arn" {
  description = "KMS key ARN for S3 components encryption"
  type        = string
}
variable "ami_name" {
  description = "Name for the created AMI"
  type        = string
}
variable "ami_description" {
  description = "Description for the created AMI"
  type        = string
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
}
variable "test_file_name" {
  description = "Test component YAML file name"
  type        = string
}
variable "component_build_path" {
  description = "Path to the build component YAML file"
  type        = string
}
variable "component_test_path" {
  description = "Path to the test component YAML file"
  type        = string
}
variable "scripts_path" {
  description = "Path to the scripts directory"
  type        = string
}
variable "s3_bucket_name" {
  description = "S3 Bucket Name for EC2 Image Builder logs and component files"
  type        = string
}
variable "build_component_arn" {
  description = "List of ARNs for the EC2 Image Builder Build Components"
  type        = list(string)
  default     = []
}
variable "test_component_arn" {
  description = "List of ARNs for the EC2 Image Builder Test Components"
  type        = list(string)
  default     = []
}
variable "attach_custom_policy" {
  description = "Attach custom policy to the EC2 Instance Profile"
  type        = bool
  default     = false
}
variable "custom_policy_arn" {
  description = "ARN of the custom policy to be attached to the EC2 Instance Profile"
  type        = string
  default     = null
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
variable "imagebuilder_image_recipe_kms_key_arn" {
  description = "KMS Key ARN(CMK) for encrypting Imagebuilder Image Recipe Block Device Mapping"
  type        = string
  default     = null
}
variable "terminate_on_failure" {
  description = "Terminate instance on failure"
  type        = bool
  default     = true
}
variable "recipe_volume_size" {
  description = "Volume Size of Imagebuilder Image Recipe Block Device Mapping"
  type        = number
  default     = 100
}
variable "recipe_volume_type" {
  description = "Volume Type of Imagebuilder Image Recipe Block Device Mapping"
  type        = string
  default     = "gp3"
}
variable "schedule_expression" {
  description = "Schedule expression for pipeline execution"
  type = list(object({
    pipeline_execution_start_condition = string,
    scheduleExpression                 = string
  }))
  default = []
}
variable "timeout" {
  description = "Number of hours before image time out"
  type        = string
  default     = "2h"
}
variable "managed_components" {
  description = "AWS managed components to include in the image recipe"
  type = list(object({
    name    = string,
    version = string
  }))
  default = []
}
variable "ami_regions_kms_key" {
  description = "AWS Regions to share the AMI with and target KMS Key in each region"
  type        = map(string)
  default     = {}
}
variable "target_account_ids" {
  description = "List of target accounts to share the AMI with"
  type        = list(string)
  default     = []
}
variable "ami_regions" {
  description = "List of regions to distribute AMIs to"
  type        = list(string)
  default     = []
}
variable "distribution_kms_key_arn" {
  description = "KMS key ARN for AMI distribution encryption"
  type        = string
  default     = null
}
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
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