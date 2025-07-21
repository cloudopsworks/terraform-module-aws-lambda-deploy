##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
resource "aws_cloudwatch_log_group" "lambda_function_logs" {
  name              = "/aws/lambda/${var.namespace}/${var.release.name}"
  retention_in_days = try(var.lambda.log_retention_days, 14)
  tags              = local.all_tags
}
