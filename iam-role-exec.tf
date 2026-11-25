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
  # These services deliver events to the function. Poll-based mappings do not.
  lambda_invoker_trigger_sources = merge(
    local.s3_trigger_enabled ? {
      "s3.amazonaws.com" = {
        arn     = data.aws_s3_bucket.notification[0].arn
        account = local.s3_source_account
      }
    } : {},
    local.sns_trigger_enabled ? {
      "sns.amazonaws.com" = {
        arn     = local.sns_topic_arn
        account = split(":", local.sns_topic_arn)[4]
      }
    } : {},
    local.eventbridge_trigger_enabled ? {
      "events.amazonaws.com" = {
        arn     = aws_cloudwatch_event_rule.lambda_function[0].arn
        account = data.aws_caller_identity.current.account_id
      }
    } : {},
    local.scheduler_enabled ? {
      "scheduler.amazonaws.com" = {
        arn     = "arn:${data.aws_partition.current.partition}:scheduler:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:schedule-group/${local.scheduler_group_name}"
        account = data.aws_caller_identity.current.account_id
      }
    } : {},
  )

  lambda_invoker_role_requested = tobool(try(var.lambda.iam.execRole.enabled, null))
  lambda_invoker_role_explicit  = local.lambda_invoker_role_requested == true
  lambda_invoker_configured_principals = local.lambda_invoker_role_requested == false ? toset([]) : toset(coalesce(
    try(tolist(var.lambda.iam.execRole.principals), null),
    local.lambda_invoker_role_explicit ? ["lambda.amazonaws.com"] : [],
  ))
  lambda_invoker_principals   = setunion(keys(local.lambda_invoker_trigger_sources), local.lambda_invoker_configured_principals)
  lambda_invoker_role_enabled = local.lambda_invoker_role_explicit || length(local.lambda_invoker_principals) > 0

  # Preserve existing explicit caller grants. Managed Scheduler is always group-scoped.
  lambda_invoker_scoped_sources = {
    for principal, source in local.lambda_invoker_trigger_sources : principal => source
    if principal == "scheduler.amazonaws.com" || !contains(local.lambda_invoker_configured_principals, principal)
  }
  lambda_invoker_unscoped_principals = setsubtract(local.lambda_invoker_principals, keys(local.lambda_invoker_scoped_sources))

  lambda_function_needs_eni = local.lambda_custom_role_enabled && try(var.lambda.vpc.enabled, false)
  lambda_invoker_needs_eni  = local.lambda_invoker_role_explicit && try(var.lambda.vpc.enabled, false)
}

data "aws_iam_policy_document" "lambda_assume_role" {
  count = local.lambda_invoker_role_enabled ? 1 : 0

  dynamic "statement" {
    for_each = length(local.lambda_invoker_unscoped_principals) > 0 ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = local.lambda_invoker_unscoped_principals
      }
    }
  }

  dynamic "statement" {
    for_each = local.lambda_invoker_scoped_sources
    content {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "Service"
        identifiers = [statement.key]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [statement.value.account]
      }
      condition {
        test     = "StringEquals"
        variable = "aws:SourceArn"
        values   = [statement.value.arn]
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

  lifecycle {
    precondition {
      condition     = length(local.lambda_invoker_principals) > 0
      error_message = "An enabled invoker role needs a direct trigger or at least one service in lambda.iam.execRole.principals."
    }
  }
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


