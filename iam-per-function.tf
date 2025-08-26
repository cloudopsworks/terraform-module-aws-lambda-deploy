##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
data "aws_iam_policy_document" "lambda_function" {
  count = try(var.lambda.iam.enabled, false) && length(try(var.lambda.iam.statements, [])) > 0 ? 1 : 0
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
  count = try(var.lambda.iam.enabled, false) && try(var.lambda.triggers.sqs.queueName, "") != "" ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:DeleteMessageBatch",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [
      data.aws_sqs_queue.notification[0].arn
    ]
  }
}

data "aws_iam_policy_document" "lambda_trigger_s3" {
  count = try(var.lambda.iam.enabled, false) && try(var.lambda.triggers.s3.bucketName, "") != "" ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "${data.aws_s3_bucket.notification[0].arn}/*",
      data.aws_s3_bucket.notification[0].arn
    ]
  }
}

data "aws_iam_policy_document" "lambda_trigger_dynamodb" {
  count = try(var.lambda.triggers.dynamodb.tableName, "") != "" ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:DescribeStream",
      "dynamodb:GetItem",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams",
      "dynamodb:PartiQLSelect",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      data.aws_dynamodb_table.notification[0].arn
    ]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_function" {
  count      = try(var.lambda.iam.enabled, false) ? length(try(var.lambda.iam.policy_attachments, [])) : 0
  role       = aws_iam_role.lambda_function[0].name
  policy_arn = var.lambda.iam.policy_attachments[count.index].arn
}

resource "aws_iam_role_policy" "lambda_function_log" {
  count  = try(var.lambda.iam.enabled, false) ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-log-role-policy"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_function_logs.json
}

resource "aws_iam_role_policy" "lambda_function_custom" {
  count  = try(var.lambda.iam.enabled, false) && length(try(var.lambda.iam.statements, [])) > 0 ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-custom-role-policy"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_function[0].json
}

resource "aws_iam_role_policy" "lambda_function_trigger_sqs" {
  count  = try(var.lambda.iam.enabled, false) && try(var.lambda.triggers.sqs.queueName, "") != "" ? 1 : 0
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_trigger_sqs[0].json
}

resource "aws_iam_role_policy" "lambda_function_trigger_s3" {
  count  = try(var.lambda.iam.enabled, false) && try(var.lambda.triggers.sqs.bucketName, "") != "" ? 1 : 0
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_trigger_s3[0].json
}

resource "aws_iam_role_policy" "lambda_function_trigger_dybamodb" {
  count  = try(var.lambda.triggers.dynamodb.tableName, "") != "" ? 1 : 0
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_trigger_dynamodb[0].json
}

resource "aws_iam_role_policy" "lambda_function_ec2" {
  count  = try(var.lambda.iam.enabled, false) && try(var.lambda.vpc.enabled, false) ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-ec2-exec-policy"
  role   = aws_iam_role.lambda_function[0].name
  policy = data.aws_iam_policy_document.lambda_exec_ec2[0].json
}
