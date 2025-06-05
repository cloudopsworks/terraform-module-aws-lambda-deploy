##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
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

resource "aws_lambda_event_source_mapping" "lambda_test_sqs_trigger" {
  count            = try(var.lambda.triggers.sqs.queueName, "") != "" ? 1 : 0
  event_source_arn = data.aws_sqs_queue.notification[0].arn
  function_name    = aws_lambda_function.lambda_function.arn

  dynamic "filter_criteria" {
    for_each = length(try(var.lambda.triggers.sqs.filterCriteria, {})) ? [1] : []
    content {
      filter {
        pattern = jsonencode(var.lambda.triggers.sqs.filterCriteria)
      }
    }
  }
}

