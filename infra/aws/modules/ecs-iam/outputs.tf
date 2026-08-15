output "execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.execution.arn

  depends_on = [
    aws_iam_role_policy.execution_secrets,
    aws_iam_role_policy_attachment.execution,
  ]
}

output "task_role_arn" {
  description = "Application task role ARN."
  value       = aws_iam_role.task.arn

  depends_on = [
    aws_iam_role_policy.ecs_exec,
    aws_iam_role_policy_attachment.cloudwatch,
    aws_iam_role_policy_attachment.xray,
  ]
}
