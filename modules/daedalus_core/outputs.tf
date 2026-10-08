output "canary_role_arn" {
  value       = aws_iam_role.canary_swift_operator.arn
  description = "ARN of Canary IAM Role"
}

output "honeytoken_secret_arn" {
  value       = aws_secretsmanager_secret.honeytoken_db_creds.arn
  description = "ARN of Honeytoken Secret"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.soc_alerts.arn
  description = "ARN of High-Priority SOC SNS Topic"
}

output "alert_log_group" {
  value       = aws_cloudwatch_log_group.soc_alert_sink.name
  description = "Encrypted CloudWatch Log Group"
}

output "cloudtrail_arn" {
  value       = try(aws_cloudtrail.daedalus_trail[0].arn, "CloudTrail Disabled")
  description = "ARN of CloudTrail (if enabled)"
}
