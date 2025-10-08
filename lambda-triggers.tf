##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

#
# S3
#
data "aws_s3_bucket" "notification" {
  count  = try(var.lambda.triggers.s3.bucketName, "") != "" ? 1 : 0
  bucket = var.lambda.triggers.s3.bucketName
}

resource "aws_lambda_permission" "allow_bucket" {
  count         = try(var.lambda.triggers.s3.bucketName, "") != "" ? 1 : 0
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.notification[0].arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = try(var.lambda.triggers.s3.bucketName, "") != "" ? 1 : 0
  bucket = data.aws_s3_bucket.notification[0].id

  lambda_function {
    id                  = format("s3-%s-%s", var.lambda.triggers.s3.bucketName, aws_lambda_function.lambda_function.function_name)
    lambda_function_arn = aws_lambda_function.lambda_function.arn
    events              = var.lambda.triggers.s3.events
    filter_prefix       = var.lambda.triggers.s3.filterPrefix
    filter_suffix       = var.lambda.triggers.s3.filterSuffix
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

#
# SQS
#
data "aws_sqs_queue" "notification" {
  count = try(var.lambda.triggers.sqs.queueName, "") != "" ? 1 : 0
  name  = var.lambda.triggers.sqs.queueName
}

resource "aws_lambda_event_source_mapping" "lambda_sqs_trigger" {
  count            = try(var.lambda.triggers.sqs.queueName, "") != "" ? 1 : 0
  event_source_arn = data.aws_sqs_queue.notification[0].arn
  function_name    = aws_lambda_function.lambda_function.arn
  batch_size       = try(var.lambda.triggers.sqs.batchSize, null)

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
}

resource "aws_lambda_permission" "allow_sqs" {
  count         = try(var.lambda.triggers.sqs.queueName, "") != "" ? 1 : 0
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = data.aws_sqs_queue.notification[0].arn
}

#
# DynamoDB
#
data "aws_dynamodb_table" "notification" {
  count = try(var.lambda.triggers.dynamodb.tableName, "") != "" ? 1 : 0
  name  = var.lambda.triggers.dynamodb.tableName
}

resource "aws_lambda_event_source_mapping" "lambda_dynamodb_trigger" {
  count                  = try(var.lambda.triggers.dynamodb.tableName, "") != "" ? 1 : 0
  event_source_arn       = data.aws_dynamodb_table.notification[0].stream_arn
  function_name          = aws_lambda_function.lambda_function.arn
  starting_position      = try(var.lambda.triggers.dynamodb.startingPosition, "LATEST")
  batch_size             = try(var.lambda.triggers.dynamodb.batchSize, null)
  maximum_retry_attempts = try(var.lambda.triggers.dynamodb.maximumRetryAttempts, null)

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
}

resource "aws_lambda_permission" "allow_dynamodb" {
  count         = try(var.lambda.triggers.dynamodb.tableName, "") != "" ? 1 : 0
  statement_id  = "AllowExecutionFromDynamoDB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "dynamodb.amazonaws.com"
  source_arn    = data.aws_dynamodb_table.notification[0].arn
}
