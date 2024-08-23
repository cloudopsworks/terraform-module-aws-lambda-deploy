##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
resource "aws_cloudwatch_log_group" "lambda_function_logs" {
  name              = "/aws/lambda/${var.namespace}/${var.release.name}"
  retention_in_days = try(var.lambda.log_retention_days, 14)
  tags              = local.all_tags
}
