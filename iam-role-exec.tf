##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
data "aws_iam_policy_document" "lambda_assume_role" {
  count = try(var.lambda.iam.execRole.enabled, false) ? 1 : 0

  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = concat(
        try(var.lambda.iam.execRole.principals, ["lambda.amazonaws.com"]),
        try(var.lambda.schedule.enabled, false) ? ["scheduler.amazonaws.com"] : []
      )
    }
  }
}

data "aws_iam_policy_document" "lambda_exec" {
  count = try(var.lambda.iam.execRole.enabled, false) ? 1 : 0
  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync"
    ]
    resources = [
      aws_lambda_function.lambda_function.arn,
      "${aws_lambda_function.lambda_function.arn}:*"
    ]
  }
}

resource "aws_iam_role" "lambda_exec" {
  count              = try(var.lambda.iam.execRole.enabled, false) ? 1 : 0
  name               = "lambda-exec-role-${var.release.name}-${local.system_name_short}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[0].json

  tags = merge({
    Release   = var.release.name
    Namespace = var.namespace
    },
    local.all_tags
  )
}

resource "aws_iam_role_policy" "lambda_exec" {
  count  = try(var.lambda.iam.execRole.enabled, false) ? 1 : 0
  name   = "exec-policy-${var.release.name}-${local.system_name_short}"
  policy = data.aws_iam_policy_document.lambda_exec[0].json
  role   = aws_iam_role.lambda_exec[0].id
}
