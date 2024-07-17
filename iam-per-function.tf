##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
data "aws_iam_policy_document" "lambda_function" {
  count = try(var.lambda.iam.enabled, false) ? 1 : 0
  dynamic "statement" {
    for_each = var.lambda.iam.statements
    content {
      effect    = statement.value.effect
      actions   = statement.value.action
      resources = statement.value.resource
    }
  }
}

resource "aws_iam_role" "lambda_function" {
  count              = try(var.lambda.iam.enabled, false) ? 1 : 0
  name               = "lambda-role-${var.release.name}-${local.system_name_short}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge({
    Release   = var.release.name
    Namespace = var.namespace
    },
    local.all_tags
  )
}

data "aws_iam_policy_document" "lambda_function_combi" {
  count = try(var.lambda.iam.enabled, false) ? 1 : 0
  source_policy_documents = [
    data.aws_iam_policy_document.lambda_function_logs.json,
    data.aws_iam_policy_document.lambda_function[0].json,
  ]
}

resource "aws_iam_role_policy" "lambda_function" {
  count  = try(var.lambda.iam.enabled, false) ? 1 : 0
  name   = "lambda-policy-${var.release.name}-${local.system_name_short}"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_function_combi[0].json
}
