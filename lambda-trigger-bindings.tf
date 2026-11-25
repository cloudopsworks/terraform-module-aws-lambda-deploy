##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  sns_topic_arn         = try(var.lambda.triggers.sns.topicArn, null)
  eventbridge_rule_name = try(var.lambda.triggers.eventbridge.ruleName, null)
  kinesis_stream_arn    = try(var.lambda.triggers.kinesis.streamArn, null)

  sns_trigger_enabled         = local.sns_topic_arn != null && local.sns_topic_arn != ""
  eventbridge_trigger_enabled = local.eventbridge_rule_name != null && local.eventbridge_rule_name != ""
  kinesis_trigger_enabled     = local.kinesis_stream_arn != null && local.kinesis_stream_arn != ""
}

resource "aws_lambda_permission" "allow_sns" {
  count         = local.sns_trigger_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = local.sns_topic_arn
}

resource "aws_sns_topic_subscription" "lambda_function" {
  count     = local.sns_trigger_enabled ? 1 : 0
  topic_arn = local.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_function.arn

  depends_on = [aws_lambda_permission.allow_sns]
}

resource "aws_cloudwatch_event_rule" "lambda_function" {
  count          = local.eventbridge_trigger_enabled ? 1 : 0
  name           = local.eventbridge_rule_name
  event_bus_name = coalesce(try(var.lambda.triggers.eventbridge.eventBusName, null), "default")
  event_pattern  = jsonencode(var.lambda.triggers.eventbridge.eventPattern)
  tags           = local.all_tags
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = local.eventbridge_trigger_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_function[0].arn
}

resource "aws_cloudwatch_event_target" "lambda_function" {
  count          = local.eventbridge_trigger_enabled ? 1 : 0
  rule           = aws_cloudwatch_event_rule.lambda_function[0].name
  event_bus_name = aws_cloudwatch_event_rule.lambda_function[0].event_bus_name
  target_id      = aws_lambda_function.lambda_function.function_name
  arn            = aws_lambda_function.lambda_function.arn

  depends_on = [aws_lambda_permission.allow_eventbridge]
}

data "aws_iam_policy_document" "lambda_trigger_kinesis" {
  count = local.kinesis_trigger_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
    ]
    resources = [local.kinesis_stream_arn]
  }
}

resource "aws_iam_role_policy" "lambda_function_trigger_kinesis" {
  count  = local.kinesis_trigger_enabled ? 1 : 0
  name   = "lambda-kinesis-read"
  role   = local.lambda_execution_role_name
  policy = data.aws_iam_policy_document.lambda_trigger_kinesis[0].json
}

resource "aws_lambda_event_source_mapping" "lambda_kinesis_trigger" {
  count                              = local.kinesis_trigger_enabled ? 1 : 0
  event_source_arn                   = local.kinesis_stream_arn
  function_name                      = aws_lambda_function.lambda_function.arn
  starting_position                  = try(var.lambda.triggers.kinesis.startingPosition, null) == null ? "LATEST" : var.lambda.triggers.kinesis.startingPosition
  batch_size                         = try(var.lambda.triggers.kinesis.batchSize, null)
  maximum_retry_attempts             = try(var.lambda.triggers.kinesis.maximumRetryAttempts, null)
  maximum_batching_window_in_seconds = try(var.lambda.triggers.kinesis.maximumBatchingWindowInSeconds, null)
  tags                               = local.all_tags

  depends_on = [aws_iam_role_policy.lambda_function_trigger_kinesis]
}
