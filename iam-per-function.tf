##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
data "aws_iam_policy_document" "lambda_function" {
  count = local.lambda_custom_role_enabled && length(try(var.lambda.iam.statements, [])) > 0 ? 1 : 0
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
  count              = local.lambda_custom_role_enabled ? 1 : 0
  name               = local.function_role_name
  path               = "/${lower(var.org.organization_name)}-${lower(var.org.organization_unit)}/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge({
    Release   = var.release.name
    Namespace = var.namespace
    },
    local.all_tags
  )
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "lambda_trigger_sqs" {
  count = local.sqs_trigger_enabled ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [
      data.aws_sqs_queue.notification[0].arn
    ]
  }
}

data "aws_iam_policy_document" "lambda_trigger_dynamodb" {
  count = local.dynamodb_trigger_enabled ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
    ]
    resources = [data.aws_dynamodb_table.notification[0].stream_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:ListStreams"]
    resources = ["*"]
  }

  # Preserve pre-existing table access for custom roles without granting it to the default role.
  dynamic "statement" {
    for_each = local.lambda_custom_role_enabled ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "dynamodb:BatchGetItem",
        "dynamodb:ConditionCheckItem",
        "dynamodb:GetItem",
        "dynamodb:PartiQLSelect",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      resources = [data.aws_dynamodb_table.notification[0].arn]
    }
  }
}

resource "aws_iam_role_policy_attachment" "lambda_function" {
  count      = local.lambda_custom_role_enabled ? length(try(var.lambda.iam.policy_attachments, [])) : 0
  role       = aws_iam_role.lambda_function[0].name
  policy_arn = var.lambda.iam.policy_attachments[count.index].arn
}

resource "aws_iam_role_policy" "lambda_function_log" {
  count  = local.lambda_custom_role_enabled ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-log-role-policy"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_function_logs.json
}

resource "aws_iam_role_policy" "lambda_function_custom" {
  count  = local.lambda_custom_role_enabled && length(try(var.lambda.iam.statements, [])) > 0 ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-custom-role-policy"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_function[0].json
}

resource "aws_iam_role_policy" "lambda_function_trigger_sqs" {
  count  = local.sqs_trigger_enabled ? 1 : 0
  role   = local.lambda_execution_role_name
  policy = data.aws_iam_policy_document.lambda_trigger_sqs[0].json
}

resource "aws_iam_role_policy" "lambda_function_trigger_dybamodb" {
  count  = local.dynamodb_trigger_enabled ? 1 : 0
  role   = local.lambda_execution_role_name
  policy = data.aws_iam_policy_document.lambda_trigger_dynamodb[0].json
}

resource "aws_iam_role_policy" "lambda_function_ec2" {
  count  = local.lambda_function_needs_eni ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-ec2-exec-policy"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_exec_ec2[0].json
}
