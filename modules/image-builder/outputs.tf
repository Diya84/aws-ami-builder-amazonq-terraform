output "image_pipeline_arn" {
  description = "ARN of the EC2 Image Builder Pipeline"
  value       = aws_imagebuilder_image_pipeline.imagebuilder_image_pipeline[0].arn
}

output "image_recipe_arn" {
  description = "ARN of the EC2 Image Builder Image Recipe"
  value       = aws_imagebuilder_image_recipe.imagebuilder_image_recipe.arn
}

output "infrastructure_configuration_arn" {
  description = "ARN of the EC2 Image Builder Infrastructure Configuration"
  value       = aws_imagebuilder_infrastructure_configuration.imagebuilder_infrastructure_configuration[0].arn
}

output "build_component_arn" {
  description = "ARN of the EC2 Image Builder Build Component"
  value       = aws_imagebuilder_component.build_component.arn
}

output "test_component_arn" {
  description = "ARN of the EC2 Image Builder Test Component"
  value       = aws_imagebuilder_component.test_component.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM Role for EC2 Image Builder"
  value       = aws_iam_role.awsserviceroleforimagebuilder.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM Instance Profile for EC2 Image Builder"
  value       = aws_iam_instance_profile.iam_instance_profile.name
}

output "security_group_id" {
  description = "ID of the Security Group for EC2 Image Builder"
  value       = var.create_security_group ? aws_security_group.security_group[0].id : null
}

output "access_logs_bucket_name" {
  description = "Name of the S3 access logs bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ARN of the S3 access logs bucket"
  value       = var.enable_access_logging ? aws_s3_bucket.access_logs[0].arn : null
}