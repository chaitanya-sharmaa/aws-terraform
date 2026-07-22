output "iam_role_arn" {
  description = "The ARN of the IAM role to associate with the Kubernetes ServiceAccount"
  value       = module.sre_agent_irsa.iam_role_arn
}

output "iam_policy_arn" {
  description = "The ARN of the IAM policy created for Bedrock access"
  value       = aws_iam_policy.sre_bedrock_policy.arn
}
