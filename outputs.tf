##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "function_name" {
  description = "Name of the deployed Lambda function, formed as \"<release.name>-<namespace>\"."
  value       = aws_lambda_function.lambda_function.function_name
}

output "function_arn" {
  description = "Unqualified ARN of the deployed Lambda function."
  value       = aws_lambda_function.lambda_function.arn
}

output "function_invoke_arn" {
  description = "ARN to be used by API Gateway and other integrations to invoke the Lambda function."
  value       = aws_lambda_function.lambda_function.invoke_arn
}

output "lambda_function_role" {
  description = "Name of the IAM role assumed by the Lambda function at runtime. Returns the dedicated function role when lambda.iam.enabled is true, otherwise the default role created by this module."
  value       = try(var.lambda.iam.enabled, false) ? aws_iam_role.lambda_function[0].name : aws_iam_role.default_lambda_function[0].name
}

output "lambda_function_role_arn" {
  description = "ARN of the IAM role assumed by the Lambda function at runtime. Returns the dedicated function role when lambda.iam.enabled is true, otherwise the default role created by this module."
  value       = try(var.lambda.iam.enabled, false) ? aws_iam_role.lambda_function[0].arn : aws_iam_role.default_lambda_function[0].arn
}

output "lambda_exec_role" {
  description = "Name of the IAM invoker role granting lambda:InvokeFunction on this function. Empty string when lambda.iam.execRole.enabled is false."
  value       = try(var.lambda.iam.execRole.enabled, false) ? aws_iam_role.lambda_exec[0].name : ""
}

output "lambda_exec_role_arn" {
  description = "ARN of the IAM invoker role granting lambda:InvokeFunction on this function. Empty string when lambda.iam.execRole.enabled is false."
  value       = try(var.lambda.iam.execRole.enabled, false) ? aws_iam_role.lambda_exec[0].arn : ""
}
