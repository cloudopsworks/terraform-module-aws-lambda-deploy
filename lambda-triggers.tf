##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

#
# S3
#
locals {
  s3_bucket_name      = try(var.lambda.triggers.s3.bucketName, null)
  sqs_queue_name      = try(var.lambda.triggers.sqs.queueName, null)
  dynamodb_table_name = try(var.lambda.triggers.dynamodb.tableName, null)

  s3_trigger_enabled       = local.s3_bucket_name != null && local.s3_bucket_name != ""
  sqs_trigger_enabled      = local.sqs_queue_name != null && local.sqs_queue_name != ""
  dynamodb_trigger_enabled = local.dynamodb_table_name != null && local.dynamodb_table_name != ""
}

data "aws_s3_bucket" "notification" {
  count  = local.s3_trigger_enabled ? 1 : 0
  bucket = local.s3_bucket_name
}

resource "aws_lambda_permission" "allow_bucket" {
  count         = local.s3_trigger_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.notification[0].arn
  source_account = coalesce(
    try(var.lambda.triggers.s3.sourceAccount, null),
    data.aws_caller_identity.current.account_id,
  )
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = local.s3_trigger_enabled ? 1 : 0
  bucket = data.aws_s3_bucket.notification[0].id

  lambda_function {
    id                  = format("s3-%s-%s", local.s3_bucket_name, aws_lambda_function.lambda_function.function_name)
    lambda_function_arn = aws_lambda_function.lambda_function.arn
    events              = var.lambda.triggers.s3.events
    filter_prefix       = try(var.lambda.triggers.s3.filterPrefix, null)
    filter_suffix       = try(var.lambda.triggers.s3.filterSuffix, null)
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

#
# SQS
#
data "aws_sqs_queue" "notification" {
  count = local.sqs_trigger_enabled ? 1 : 0
  name  = local.sqs_queue_name
}

resource "aws_lambda_event_source_mapping" "lambda_sqs_trigger" {
  count                              = local.sqs_trigger_enabled ? 1 : 0
  event_source_arn                   = data.aws_sqs_queue.notification[0].arn
  function_name                      = aws_lambda_function.lambda_function.arn
  batch_size                         = try(var.lambda.triggers.sqs.batchSize, null)
  maximum_batching_window_in_seconds = try(var.lambda.triggers.sqs.maximumBatchingWindowInSeconds, null)

  dynamic "metrics_config" {
    for_each = try(var.lambda.triggers.sqs.metricsConfig, false) ? [1] : []
    content {
      metrics = ["EventCount"]
    }
  }

  dynamic "scaling_config" {
    for_each = try(var.lambda.triggers.sqs.maximumConcurrency, 0) >= 2 ? [1] : []
    content {
      maximum_concurrency = var.lambda.triggers.sqs.maximumConcurrency
    }
  }

  dynamic "filter_criteria" {
    for_each = length(try(var.lambda.triggers.sqs.filterCriteria, [])) > 0 ? [1] : []
    content {
      dynamic "filter" {
        for_each = var.lambda.triggers.sqs.filterCriteria
        content {
          pattern = try(filter.value.pattern, jsonencode(filter.value.pattern_object))
        }
      }
    }
  }
  tags = local.all_tags

  depends_on = [aws_iam_role_policy.lambda_function_trigger_sqs]
}

#
# DynamoDB
#
data "aws_dynamodb_table" "notification" {
  count = local.dynamodb_trigger_enabled ? 1 : 0
  name  = local.dynamodb_table_name
}

resource "aws_lambda_event_source_mapping" "lambda_dynamodb_trigger" {
  count                              = local.dynamodb_trigger_enabled ? 1 : 0
  event_source_arn                   = data.aws_dynamodb_table.notification[0].stream_arn
  function_name                      = aws_lambda_function.lambda_function.arn
  starting_position                  = try(var.lambda.triggers.dynamodb.startingPosition, "LATEST")
  batch_size                         = try(var.lambda.triggers.dynamodb.batchSize, null)
  maximum_retry_attempts             = try(var.lambda.triggers.dynamodb.maximumRetryAttempts, null)
  maximum_batching_window_in_seconds = try(var.lambda.triggers.dynamodb.maximumBatchingWindowInSeconds, null)

  dynamic "metrics_config" {
    for_each = try(var.lambda.triggers.dynamodb.metricsConfig, false) ? [1] : []
    content {
      metrics = ["EventCount"]
    }
  }

  dynamic "filter_criteria" {
    for_each = length(try(var.lambda.triggers.dynamodb.filterCriteria, [])) > 0 ? [1] : []
    content {
      dynamic "filter" {
        for_each = var.lambda.triggers.dynamodb.filterCriteria
        content {
          pattern = try(filter.value.pattern, jsonencode(filter.value.pattern_object))
        }
      }
    }
  }
  tags = local.all_tags

  depends_on = [aws_iam_role_policy.lambda_function_trigger_dybamodb]

  lifecycle {
    precondition {
      condition     = try(length(data.aws_dynamodb_table.notification[0].stream_arn) > 0, false)
      error_message = "The table specified in lambda.triggers.dynamodb.tableName must have DynamoDB Streams enabled."
    }
  }
}
