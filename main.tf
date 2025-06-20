##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
locals {
  release_tags = merge(var.extra_tags, {
    Environment = format("%s-%s", var.release.name, var.namespace)
    Namespace   = var.namespace
    Release     = var.release.name
  })
}

resource "aws_lambda_function" "lambda_function" {
  function_name                  = format("%s-%s", var.release.name, var.namespace)
  description                    = "Lambda ${var.release.name}@${var.release.source.version} - ${local.system_name}"
  role                           = try(var.lambda.iam.enabled, false) ? aws_iam_role.lambda_function[0].arn : aws_iam_role.default_lambda_function[0].arn
  handler                        = var.lambda.handler
  runtime                        = var.lambda.runtime
  s3_bucket                      = var.versions_bucket
  s3_key                         = var.bucket_path
  package_type                   = "Zip"
  memory_size                    = try(var.lambda.memory_size, 128)
  reserved_concurrent_executions = try(var.lambda.reserved_concurrency, -1)
  timeout                        = try(var.lambda.timeout, 3)
  publish                        = true
  layers = [
    for layer in try(var.lambda.layers, []) : layer.arn
  ]
  #  publish                        = tobool(local.publish_conf[each.key])
  #source_code_hash = base64sha256(format("%s-%s", file(".values_hash_${var.release.name}"), each.value.release.source.version))

  dynamic "vpc_config" {
    for_each = try(var.lambda.vpc.enabled, false) ? [1] : []
    content {
      security_group_ids = try(var.lambda.vpc.create_security_group, false) ? [aws_security_group.this[0].id] : var.lambda.vpc.security_groups
      subnet_ids         = var.lambda.vpc.subnets
    }
  }

  environment {
    variables = {
      for item in var.lambda.environment.variables :
      item.name => item.value
    }
  }

  logging_config {
    application_log_level = try(var.lambda.logging.application_log_level, null)
    log_format            = try(var.lambda.logging.log_format, "JSON")
    log_group             = aws_cloudwatch_log_group.lambda_function_logs.name
    system_log_level      = try(var.lambda.logging.system_log_level, null)
  }

  dynamic "ephemeral_storage" {
    for_each = try(var.lambda.ephemeral_storage.enabled, false) ? [1] : []
    content {
      size = try(var.lambda.ephemeral_storage.size, 512)
    }
  }

  dynamic "file_system_config" {
    for_each = try(var.lambda.efs.enabled, false) ? [1] : []
    content {
      arn              = var.lambda.efs.arn
      local_mount_path = var.lambda.efs.local_mount_path
    }
  }

  dynamic "tracing_config" {
    for_each = try(var.lambda.tracing.enabled, false) ? [1] : []
    content {
      mode = var.lambda.tracing.mode
    }
  }

  tags = merge(local.release_tags, local.all_tags)

  depends_on = [
    aws_iam_role_policy_attachment.lambda_function_logs,
    aws_cloudwatch_log_group.lambda_function_logs,
  ]
}

resource "aws_lambda_function_url" "lambda_function" {
  for_each = {
    for item in var.lambda.functionUrls : item.id => item
  }
  function_name      = aws_lambda_function.lambda_function.arn
  qualifier          = each.value.qualifier != "" ? each.value.qualifier : "$LATEST"
  authorization_type = each.value.authorization_type != "" ? each.value.authorization_type : "NONE"

  dynamic "cors" {
    for_each = [each.value.cors]
    content {
      allow_credentials = try(cors.value.allowCredentials, false)
      allow_headers     = try(cors.value.allowHeaders, [])
      allow_methods     = try(cors.value.allowMethods, [])
      allow_origins     = try(cors.value.allowOrigins, [])
      expose_headers    = try(cors.value.exposeHeaders, [])
      max_age           = try(cors.value.maxAge, 600)
    }
  }
}

resource "aws_lambda_provisioned_concurrency_config" "lambda_function" {
  count                             = try(var.lambda.provisioned_concurrency, 0) > 0 ? 1 : 0
  function_name                     = aws_lambda_function.lambda_function.function_name
  qualifier                         = aws_lambda_function.lambda_function.version
  provisioned_concurrent_executions = var.lambda.provisioned_concurrency
}

resource "aws_lambda_alias" "lambda_function" {
  count            = try(var.lambda.alias.enabled, false) ? 1 : 0
  name             = var.lambda.alias.name
  function_name    = aws_lambda_function.lambda_function.function_name
  function_version = aws_lambda_function.lambda_function.version
  description      = "Alias for ${var.release.name} - ${var.namespace}"
  dynamic "routing_config" {
    for_each = length(try(var.lambda.alias.routing_config, [])) > 0 ? [1] : []
    content {
      additional_version_weights = {
        for item in try(var.lambda.alias.routing_config, []) :
        item.version => item.weight
      }
    }
  }
}