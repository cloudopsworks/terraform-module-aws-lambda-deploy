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
        try(var.lambda.schedule.enabled, false) || length(try(var.lambda.schedule.multiple, [])) > 0 ? ["scheduler.amazonaws.com"] : []
      )
    }
  }
}

data "aws_iam_policy_document" "lambda_exec" {
  count = try(var.lambda.iam.execRole.enabled, false) ? 1 : 0
  statement {
    effect = "Allow"
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
  name               = "${var.release.name}-${var.namespace}-exec-role"
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
  count  = try(var.lambda.iam.execRole.enabled, false) ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-exec-policy"
  policy = data.aws_iam_policy_document.lambda_exec[0].json
  role   = aws_iam_role.lambda_exec[0].id
}


data "aws_iam_policy_document" "lambda_exec_ec2" {
  count   = try(var.lambda.iam.execRole.enabled, false) && try(var.lambda.vpc.enabled, false) ? 1 : 0
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
  count  = try(var.lambda.iam.execRole.enabled, false) && try(var.lambda.vpc.enabled, false) ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-ec2-exec-policy"
  policy = data.aws_iam_policy_document.lambda_exec_ec2[0].json
  role   = aws_iam_role.lambda_exec[0].id
}


