output "vpc_id" {
  description = "ID of the existing VPC"
  value       = data.aws_vpc.existing.id
}

output "subnet_ids" {
  description = "List of subnet IDs used"
  value       = var.subnet_ids
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for components"
  value       = aws_s3_bucket.components_bucket.id
}

output "kms_events_log_group" {
  description = "CloudWatch Log Group for KMS events"
  value       = aws_cloudwatch_log_group.kms_events.name
}
