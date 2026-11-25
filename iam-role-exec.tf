##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
data "aws_partition" "current" {}

locals {
  lambda_invoker_role_explicit = try(var.lambda.iam.execRole.enabled, false)
  lambda_invoker_role_enabled  = local.lambda_invoker_role_explicit || local.scheduler_enabled
  lambda_invoker_principals = [
    for principal in try(var.lambda.iam.execRole.principals, ["lambda.amazonaws.com"]) : principal
    if !local.scheduler_enabled || principal != "scheduler.amazonaws.com"
  ]

  lambda_function_needs_eni = local.lambda_custom_role_enabled && try(var.lambda.vpc.enabled, false)
  lambda_invoker_needs_eni  = local.lambda_invoker_role_explicit && try(var.lambda.vpc.enabled, false)
}

data "aws_iam_policy_document" "lambda_assume_role" {
  count = local.lambda_invoker_role_enabled ? 1 : 0

  dynamic "statement" {
    for_each = local.lambda_invoker_role_explicit && length(local.lambda_invoker_principals) > 0 ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = local.lambda_invoker_principals
      }
    }
  }

  dynamic "statement" {
    for_each = local.scheduler_enabled ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = ["scheduler.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values = [
          "arn:${data.aws_partition.current.partition}:scheduler:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:schedule-group/${local.scheduler_group_name}",
        ]
      }
    }
  }
}

data "aws_iam_policy_document" "lambda_exec" {
  count = local.lambda_invoker_role_enabled ? 1 : 0
  statement {
    effect  = "Allow"
    actions = local.lambda_invoker_role_explicit ? ["lambda:InvokeFunction", "lambda:InvokeAsync"] : ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.lambda_function.arn,
      "${aws_lambda_function.lambda_function.arn}:*"
    ]
  }
}

resource "aws_iam_role" "lambda_exec" {
  count              = local.lambda_invoker_role_enabled ? 1 : 0
  name               = local.exec_role_name
  path               = "/${lower(var.org.organization_name)}-${lower(var.org.organization_unit)}/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[0].json
  tags = merge({
    Release   = var.release.name
    Namespace = var.namespace
    },
    local.all_tags
  )
}

resource "aws_iam_role_policy" "lambda_exec" {
  count  = local.lambda_invoker_role_enabled ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-exec-policy"
  policy = data.aws_iam_policy_document.lambda_exec[0].json
  role   = aws_iam_role.lambda_exec[0].id
}


data "aws_iam_policy_document" "lambda_exec_ec2" {
  count   = local.lambda_function_needs_eni || local.lambda_invoker_needs_eni ? 1 : 0
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_exec_ec2" {
  count  = local.lambda_invoker_needs_eni ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-ec2-exec-policy"
  policy = data.aws_iam_policy_document.lambda_exec_ec2[0].json
  role   = aws_iam_role.lambda_exec[0].id
}


