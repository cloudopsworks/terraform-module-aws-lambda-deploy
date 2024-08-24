##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#

output "lambda_exec_role_arn" {
  value = try(var.lambda.iam.execRole.enabled, false) ? aws_iam_role.lambda_exec[0].arn : ""
}

output "lambda_exec_role" {
  value = try(var.lambda.iam.execRole.enabled, false) ? aws_iam_role.lambda_exec[0].name : ""
}

output "lambda_default_role_arn" {
  value = aws_iam_role.default_lambda_function.arn
}

output "lambda_default_role" {
  value = aws_iam_role.default_lambda_function.name
}

output "lambda_function_role_arn" {
  value = try(var.lambda.iam.enabled, false) ? aws_iam_role.lambda_function[0].arn : ""
}

output "lambda_function_role" {
  value = try(var.lambda.iam.enabled, false) ? aws_iam_role.lambda_function[0].name : ""
}

output "function_arn" {
  value = aws_lambda_function.lambda_function.arn
}

output "function_invoke_arn" {
  value = aws_lambda_function.lambda_function.invoke_arn
}

output "function_name" {
  value = aws_lambda_function.lambda_function.function_name
}
