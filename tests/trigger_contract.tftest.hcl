# Terraform defers computed resource ARNs until apply. Keep this suite portable;
# trigger_arns.tofutest.hcl checks the downstream ARN wiring at plan time.
mock_provider "aws" {
  # A syntactically valid placeholder for provider-rendered JSON; assertions
  # inspect the configured IAM statements, not this mocked output.
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_s3_bucket" {
    defaults = {
      id  = "incoming-documents"
      arn = "arn:aws:s3:::incoming-documents"
    }
  }
  mock_data "aws_sqs_queue" {
    defaults = { arn = "arn:aws:sqs:us-east-1:123456789012:orders" }
  }
  mock_data "aws_dynamodb_table" {
    defaults = {
      arn        = "arn:aws:dynamodb:us-east-1:123456789012:table/orders"
      stream_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/orders/stream/2026-01-01T00:00:00.000"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/ingest-test-logs-policy" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/example-platform/ingest-test-default-role" }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn           = "arn:aws:lambda:us-east-1:123456789012:function:ingest-test"
      qualified_arn = "arn:aws:lambda:us-east-1:123456789012:function:ingest-test:1"
    }
  }

  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/commerce/orders-created" }
  }
}

override_resource {
  target = aws_iam_role.lambda_exec
  values = {
    arn = "arn:aws:iam::123456789012:role/example-platform/ingest-test-exec-role"
  }
}

variables {
  org = {
    organization_name = "example"
    organization_unit = "platform"
    environment_name  = "test"
    environment_type  = "testing"
  }
  namespace        = "test"
  repository_owner = "example"
  versions_bucket  = "test-artifacts"
  bucket_path      = "lambda/ingest.zip"
  release = {
    name   = "ingest"
    source = { version = "1.0.0" }
  }

}

run "absent_triggers_and_tracing" {
  command = plan
  variables {
    lambda = jsondecode(file("tests/fixtures/lambda.json"))
  }

  assert {
    condition = alltrue([
      length(aws_s3_bucket_notification.bucket_notification) == 0,
      length(aws_lambda_event_source_mapping.lambda_sqs_trigger) == 0,
      length(aws_lambda_event_source_mapping.lambda_dynamodb_trigger) == 0,
      length(aws_lambda_event_source_mapping.lambda_kinesis_trigger) == 0,
      length(aws_sns_topic_subscription.lambda_function) == 0,
      length(aws_cloudwatch_event_rule.lambda_function) == 0,
      length(aws_cloudwatch_event_target.lambda_function) == 0,
      length(aws_scheduler_schedule.lambda_function) == 0,
      length(aws_scheduler_schedule.multiple_schedule) == 0,
      length(aws_scheduler_schedule_group.environ) == 0,
      length(aws_iam_role_policy.lambda_function_xray) == 0,
      length(aws_iam_role.lambda_exec) == 0,
      output.lambda_exec_role == "",
      output.lambda_exec_role_arn == "",
    ])
    error_message = "Default Lambda must not create event bindings, schedules, X-Ray grants, or an invoker role."
  }
}

run "null_and_empty_trigger_selectors" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = {
        s3          = { bucketName = "" }
        sqs         = { queueName = null }
        dynamodb    = { tableName = "" }
        sns         = { topicArn = null }
        eventbridge = { ruleName = "" }
        kinesis     = { streamArn = null }
      }
    })
  }

  assert {
    condition = alltrue([
      length(aws_s3_bucket_notification.bucket_notification) == 0,
      length(aws_lambda_event_source_mapping.lambda_sqs_trigger) == 0,
      length(aws_lambda_event_source_mapping.lambda_dynamodb_trigger) == 0,
      length(aws_lambda_event_source_mapping.lambda_kinesis_trigger) == 0,
      length(aws_sns_topic_subscription.lambda_function) == 0,
      length(aws_cloudwatch_event_target.lambda_function) == 0,
    ])
    error_message = "Empty and null selectors must disable their bindings."
  }
}

run "active_tracing_defaults_to_function_role" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), { tracing = { enabled = true } })
  }

  assert {
    condition = (
      one(aws_lambda_function.lambda_function.tracing_config).mode == "Active" &&
      aws_iam_role_policy.lambda_function_xray[0].role == aws_iam_role.default_lambda_function[0].name &&
      output.lambda_function_role == aws_iam_role.default_lambda_function[0].name &&
      toset(one(data.aws_iam_policy_document.lambda_function_xray[0].statement).actions) == toset(["xray:PutTraceSegments", "xray:PutTelemetryRecords"]) &&
      toset(one(data.aws_iam_policy_document.lambda_function_xray[0].statement).resources) == toset(["*"]) &&
      length(aws_iam_role.lambda_exec) == 0
    )
    error_message = "Opting into tracing should default to Active and grant only X-Ray writes on the default function role."
  }
}

run "pass_through_does_not_add_xray_grant" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), { tracing = { enabled = true, mode = "PassThrough" } })
  }

  assert {
    condition     = one(aws_lambda_function.lambda_function.tracing_config).mode == "PassThrough" && length(aws_iam_role_policy.lambda_function_xray) == 0
    error_message = "Explicit PassThrough must not add the automatic X-Ray write grant."
  }
}

run "all_triggers_can_share_one_traced_function" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      iam     = { enabled = true }
      tracing = { enabled = true, mode = "Active" }
      schedule = {
        enabled        = true
        schedule_group = ""
        expression     = "rate(15 minutes)"
        payload        = { mode = "reconcile" }
        multiple = [{
          expression = "cron(0 4 * * ? *)"
          timezone   = "Europe/Dublin"
          suspended  = true
        }]
      }
      triggers = {
        s3 = {
          bucketName    = "incoming-documents"
          events        = ["s3:ObjectCreated:*"]
          filterPrefix  = "reports/"
          filterSuffix  = ".json"
          sourceAccount = "210987654321"
        }
        sqs = {
          queueName                      = "orders"
          batchSize                      = 20
          maximumBatchingWindowInSeconds = 5
          maximumConcurrency             = 3
          metricsConfig                  = true
          filterCriteria                 = [{ pattern_object = { body = { type = ["order"] } } }]
        }
        dynamodb = {
          tableName                      = "orders"
          startingPosition               = "TRIM_HORIZON"
          batchSize                      = 50
          maximumBatchingWindowInSeconds = 10
          maximumRetryAttempts           = 2
          metricsConfig                  = true
          filterCriteria                 = [{ pattern = "{\"dynamodb\":{\"Keys\":{\"orderId\":{\"S\":[\"order-42\"]}}}}" }]
        }
        sns = { topicArn = "arn:aws:sns:us-east-1:123456789012:order-notifications" }
        eventbridge = {
          ruleName     = "orders-created"
          eventBusName = "commerce"
          eventPattern = { source = ["app.orders"], "detail-type" = ["OrderCreated"] }
        }
        kinesis = {
          streamArn                      = "arn:aws:kinesis:us-east-1:123456789012:stream/order-events"
          startingPosition               = "TRIM_HORIZON"
          batchSize                      = 25
          maximumBatchingWindowInSeconds = 4
          maximumRetryAttempts           = 3
        }
      }
    })
  }

  assert {
    condition = (
      one(aws_lambda_function.lambda_function.tracing_config).mode == "Active" &&
      aws_iam_role_policy.lambda_function_xray[0].role == aws_iam_role.lambda_function[0].name &&
      aws_iam_role_policy.lambda_function_xray[0].role != aws_iam_role.lambda_exec[0].name
    )
    error_message = "Only the Lambda execution role, not the separate Scheduler invoker, should get the X-Ray grant."
  }

  assert {
    condition = (
      aws_lambda_permission.allow_bucket[0].function_name == output.function_name &&
      aws_lambda_permission.allow_bucket[0].principal == "s3.amazonaws.com" &&
      aws_lambda_permission.allow_bucket[0].source_arn == "arn:aws:s3:::incoming-documents" &&
      aws_lambda_permission.allow_bucket[0].source_account == "210987654321" &&
      aws_s3_bucket_notification.bucket_notification[0].bucket == "incoming-documents" &&
      toset(one(aws_s3_bucket_notification.bucket_notification[0].lambda_function).events) == toset(["s3:ObjectCreated:*"]) &&
      one(aws_s3_bucket_notification.bucket_notification[0].lambda_function).filter_prefix == "reports/" &&
      one(aws_s3_bucket_notification.bucket_notification[0].lambda_function).filter_suffix == ".json"
    )
    error_message = "The S3 notification should preserve explicit filters and use bucket- and owner-scoped invoke permissions."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.lambda_sqs_trigger[0].event_source_arn == "arn:aws:sqs:us-east-1:123456789012:orders" &&
      aws_lambda_event_source_mapping.lambda_sqs_trigger[0].batch_size == 20 &&
      aws_lambda_event_source_mapping.lambda_sqs_trigger[0].maximum_batching_window_in_seconds == 5 &&
      one(aws_lambda_event_source_mapping.lambda_sqs_trigger[0].scaling_config).maximum_concurrency == 3 &&
      contains(one(aws_lambda_event_source_mapping.lambda_sqs_trigger[0].metrics_config).metrics, "EventCount") &&
      jsondecode(one(one(aws_lambda_event_source_mapping.lambda_sqs_trigger[0].filter_criteria).filter).pattern).body.type[0] == "order" &&
      aws_iam_role_policy.lambda_function_trigger_sqs[0].role == output.lambda_function_role &&
      toset(one(data.aws_iam_policy_document.lambda_trigger_sqs[0].statement).resources) == toset(["arn:aws:sqs:us-east-1:123456789012:orders"]) &&
      contains(one(data.aws_iam_policy_document.lambda_trigger_sqs[0].statement).actions, "sqs:ReceiveMessage")
    )
    error_message = "The SQS poller should preserve batching, scaling, metrics and filters and grant queue-scoped reads to Lambda."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].event_source_arn == data.aws_dynamodb_table.notification[0].stream_arn &&
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].event_source_arn != data.aws_dynamodb_table.notification[0].arn &&
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].starting_position == "TRIM_HORIZON" &&
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].batch_size == 50 &&
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].maximum_retry_attempts == 2 &&
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].maximum_batching_window_in_seconds == 10 &&
      contains(one(aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].metrics_config).metrics, "EventCount") &&
      jsondecode(one(one(aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].filter_criteria).filter).pattern).dynamodb.Keys.orderId.S[0] == "order-42" &&
      aws_iam_role_policy.lambda_function_trigger_dybamodb[0].role == output.lambda_function_role &&
      anytrue([
        for statement in data.aws_iam_policy_document.lambda_trigger_dynamodb[0].statement :
        toset(statement.resources) == toset([data.aws_dynamodb_table.notification[0].stream_arn]) &&
        toset(statement.actions) == toset(["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator"])
      ]) &&
      anytrue([
        for statement in data.aws_iam_policy_document.lambda_trigger_dynamodb[0].statement :
        toset(statement.resources) == toset([data.aws_dynamodb_table.notification[0].arn]) &&
        contains(statement.actions, "dynamodb:GetItem")
      ])
    )
    error_message = "The DynamoDB poller must read the stream with the configured mapping settings, without losing legacy custom-role table reads."
  }

  assert {
    condition = (
      aws_sns_topic_subscription.lambda_function[0].topic_arn == "arn:aws:sns:us-east-1:123456789012:order-notifications" &&
      aws_sns_topic_subscription.lambda_function[0].protocol == "lambda" &&
      aws_lambda_permission.allow_sns[0].function_name == output.function_name &&
      aws_lambda_permission.allow_sns[0].principal == "sns.amazonaws.com" &&
      aws_lambda_permission.allow_sns[0].source_arn == aws_sns_topic_subscription.lambda_function[0].topic_arn
    )
    error_message = "SNS must subscribe the function and grant invocation solely to the supplied topic."
  }

  assert {
    condition = (
      aws_cloudwatch_event_rule.lambda_function[0].name == "orders-created" &&
      aws_cloudwatch_event_rule.lambda_function[0].event_bus_name == "commerce" &&
      jsondecode(aws_cloudwatch_event_rule.lambda_function[0].event_pattern).source[0] == "app.orders" &&
      jsondecode(aws_cloudwatch_event_rule.lambda_function[0].event_pattern)["detail-type"][0] == "OrderCreated" &&
      aws_cloudwatch_event_target.lambda_function[0].rule == "orders-created" &&
      aws_cloudwatch_event_target.lambda_function[0].event_bus_name == "commerce" &&
      aws_cloudwatch_event_target.lambda_function[0].target_id == output.function_name &&
      aws_lambda_permission.allow_eventbridge[0].function_name == output.function_name &&
      aws_lambda_permission.allow_eventbridge[0].principal == "events.amazonaws.com"
    )
    error_message = "The event pattern must be encoded once, with the rule and target on the chosen bus, and an EventBridge invocation grant on the function."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].event_source_arn == "arn:aws:kinesis:us-east-1:123456789012:stream/order-events" &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].starting_position == "TRIM_HORIZON" &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].batch_size == 25 &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].maximum_retry_attempts == 3 &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].maximum_batching_window_in_seconds == 4 &&
      aws_iam_role_policy.lambda_function_trigger_kinesis[0].role == output.lambda_function_role &&
      toset(one(data.aws_iam_policy_document.lambda_trigger_kinesis[0].statement).resources) == toset([aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].event_source_arn]) &&
      toset(one(data.aws_iam_policy_document.lambda_trigger_kinesis[0].statement).actions) == toset([
        "kinesis:DescribeStream", "kinesis:DescribeStreamSummary", "kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:ListShards",
      ])
    )
    error_message = "Kinesis should use the specified stream, batching and retry settings and grant only the required stream reads."
  }

  assert {
    condition = (
      aws_scheduler_schedule_group.environ[0].name == "sched-grp-ingest-test" &&
      aws_scheduler_schedule.lambda_function[0].group_name == "sched-grp-ingest-test" &&
      aws_scheduler_schedule.multiple_schedule["sched-ingest-test-0"].group_name == "sched-grp-ingest-test" &&
      aws_scheduler_schedule.multiple_schedule["sched-ingest-test-0"].schedule_expression_timezone == "Europe/Dublin" &&
      aws_scheduler_schedule.multiple_schedule["sched-ingest-test-0"].state == "DISABLED" &&
      jsondecode(one(aws_scheduler_schedule.lambda_function[0].target).input).mode == "reconcile" &&
      output.lambda_exec_role == "ingest-test-exec-role" &&
      toset(one(data.aws_iam_policy_document.lambda_exec[0].statement).actions) == toset(["lambda:InvokeFunction"]) &&
      toset(one(one(data.aws_iam_policy_document.lambda_assume_role[0].statement).principals).identifiers) == toset(["scheduler.amazonaws.com"]) &&
      anytrue([
        for condition in one(data.aws_iam_policy_document.lambda_assume_role[0].statement).condition :
        condition.variable == "aws:SourceAccount" && toset(condition.values) == toset(["123456789012"])
      ]) &&
      anytrue([
        for condition in one(data.aws_iam_policy_document.lambda_assume_role[0].statement).condition :
        condition.variable == "aws:SourceArn" &&
        toset(condition.values) == toset(["arn:aws:scheduler:us-east-1:123456789012:schedule-group/sched-grp-ingest-test"])
      ])
    )
    error_message = "Both schedule paths must share the generated group; the implicit invoker must trust only Scheduler, scoped to that group and account."
  }
}

run "basic_triggers_need_no_custom_role_or_optional_filters" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      schedule = { enabled = true, expression = "rate(1 hour)" }
      triggers = {
        s3          = { bucketName = "incoming-documents", events = ["s3:ObjectCreated:*"] }
        sqs         = { queueName = "orders" }
        dynamodb    = { tableName = "orders" }
        eventbridge = { ruleName = "orders-created", eventPattern = { source = ["app.orders"] } }
        kinesis     = { streamArn = "arn:aws:kinesis:us-east-1:123456789012:stream/order-events" }
      }
    })
  }

  override_resource {
    target = aws_cloudwatch_event_rule.lambda_function
    values = { arn = "arn:aws:events:us-east-1:123456789012:rule/orders-created" }
  }

  assert {
    condition = (
      length(aws_iam_role.lambda_function) == 0 &&
      output.lambda_function_role == aws_iam_role.default_lambda_function[0].name &&
      aws_iam_role_policy.lambda_function_trigger_sqs[0].role == output.lambda_function_role &&
      aws_iam_role_policy.lambda_function_trigger_dybamodb[0].role == output.lambda_function_role &&
      aws_iam_role_policy.lambda_function_trigger_kinesis[0].role == output.lambda_function_role &&
      aws_lambda_event_source_mapping.lambda_dynamodb_trigger[0].starting_position == "LATEST" &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].starting_position == "LATEST" &&
      alltrue([
        for statement in data.aws_iam_policy_document.lambda_trigger_dynamodb[0].statement :
        !contains(statement.resources, data.aws_dynamodb_table.notification[0].arn)
      ])
    )
    error_message = "The default Lambda role should get pull permissions, but DynamoDB table reads belong only to the legacy custom role."
  }

  assert {
    condition = (
      aws_lambda_permission.allow_bucket[0].source_account == "123456789012" &&
      coalesce(one(aws_s3_bucket_notification.bucket_notification[0].lambda_function).filter_prefix, "-") == "-" &&
      coalesce(one(aws_s3_bucket_notification.bucket_notification[0].lambda_function).filter_suffix, "-") == "-"
    )
    error_message = "Omitted S3 filters must not restrict object keys; absent sourceAccount uses the current account."
  }

  assert {
    condition = (
      aws_cloudwatch_event_rule.lambda_function[0].event_bus_name == "default" &&
      aws_cloudwatch_event_target.lambda_function[0].event_bus_name == "default" &&
      aws_scheduler_schedule.lambda_function[0].group_name == aws_scheduler_schedule_group.environ[0].name
    )
    error_message = "An omitted bus name must use the default bus, and an omitted schedule group must use the module-created group."
  }
}

run "explicit_invoker_preserves_other_trust_for_existing_schedule_group" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      iam = {
        execRole = {
          enabled    = true
          principals = ["ec2.amazonaws.com", "scheduler.amazonaws.com"]
        }
      }
      schedule = {
        schedule_group = "shared-scheduling"
        multiple       = [{ expression = "rate(3 hours)" }]
      }
    })
  }

  assert {
    condition = (
      length(aws_scheduler_schedule_group.environ) == 0 &&
      length(aws_scheduler_schedule.lambda_function) == 0 &&
      aws_scheduler_schedule.multiple_schedule["sched-ingest-test-0"].group_name == "shared-scheduling" &&
      output.lambda_exec_role == "ingest-test-exec-role" &&
      toset(one(data.aws_iam_policy_document.lambda_exec[0].statement).actions) == toset(["lambda:InvokeFunction", "lambda:InvokeAsync"])
    )
    error_message = "Multiple-only schedules must reuse the named group and preserve explicitly enabled invoker permissions."
  }

  assert {
    condition = (
      length(data.aws_iam_policy_document.lambda_assume_role[0].statement) == 2 &&
      anytrue([
        for statement in data.aws_iam_policy_document.lambda_assume_role[0].statement :
        toset(one(statement.principals).identifiers) == toset(["ec2.amazonaws.com"]) && length(statement.condition) == 0
      ]) &&
      anytrue([
        for statement in data.aws_iam_policy_document.lambda_assume_role[0].statement :
        toset(one(statement.principals).identifiers) == toset(["scheduler.amazonaws.com"]) &&
        anytrue([
          for condition in statement.condition : condition.variable == "aws:SourceArn" &&
          toset(condition.values) == toset(["arn:aws:scheduler:us-east-1:123456789012:schedule-group/shared-scheduling"])
        ])
      ])
    )
    error_message = "The explicit non-Scheduler principal should retain its own trust, separate from the condition-scoped Scheduler principal."
  }
}

run "invalid_tracing_mode_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      tracing = { enabled = true, mode = "invalid" }
    })
  }
  expect_failures = [var.lambda]
}

run "blank_tracing_mode_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      tracing = { enabled = true, mode = "" }
    })
  }
  expect_failures = [var.lambda]
}

run "fifo_sns_topic_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = { sns = { topicArn = "arn:aws:sns:us-east-1:123456789012:order-notifications.fifo" } }
    })
  }
  expect_failures = [var.lambda]
}

run "rule_without_event_pattern_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = { eventbridge = { ruleName = "orders-created" } }
    })
  }
  expect_failures = [var.lambda]
}

run "raw_event_pattern_string_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = {
        eventbridge = {
          ruleName     = "orders-created"
          eventPattern = "{\"source\":[\"app.orders\"]}"
        }
      }
    })
  }
  expect_failures = [var.lambda]
}

run "kinesis_enhanced_fanout_consumer_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = {
        kinesis = { streamArn = "arn:aws:kinesis:us-east-1:123456789012:stream/order-events/consumer/worker:1540591608" }
      }
    })
  }
  expect_failures = [var.lambda]
}

run "kinesis_at_timestamp_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = {
        kinesis = {
          streamArn        = "arn:aws:kinesis:us-east-1:123456789012:stream/order-events"
          startingPosition = "AT_TIMESTAMP"
        }
      }
    })
  }
  expect_failures = [var.lambda]
}

run "blank_kinesis_starting_position_is_rejected" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = {
        kinesis = {
          streamArn        = "arn:aws:kinesis:us-east-1:123456789012:stream/order-events"
          startingPosition = ""
        }
      }
    })
  }
  expect_failures = [var.lambda]
}

run "dedicated_vpc_role_with_implicit_scheduler" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      iam      = { enabled = true }
      tracing  = { enabled = true, mode = null }
      schedule = { enabled = true, expression = "rate(1 hour)" }
      vpc = {
        enabled         = true
        subnets         = ["subnet-0123456789abcdef0"]
        security_groups = ["sg-0123456789abcdef0"]
      }
    })
  }

  assert {
    condition = (
      aws_iam_role_policy.lambda_function_ec2[0].role == output.lambda_function_role &&
      aws_iam_role_policy.lambda_function_xray[0].role == output.lambda_function_role &&
      output.lambda_exec_role != output.lambda_function_role &&
      length(aws_iam_role_policy.lambda_exec_ec2) == 0 &&
      anytrue([
        for statement in data.aws_iam_policy_document.lambda_exec_ec2[0].statement :
        contains(statement.actions, "ec2:CreateNetworkInterface")
      ])
    )
    error_message = "A traced VPC Lambda must receive ENI permissions on its dedicated function role, not the implicit Scheduler invoker."
  }
}

run "dynamodb_requires_an_enabled_stream" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      triggers = { dynamodb = { tableName = "orders" } }
    })
  }

  override_data {
    target = data.aws_dynamodb_table.notification
    values = {
      arn        = "arn:aws:dynamodb:us-east-1:123456789012:table/orders"
      stream_arn = ""
    }
  }

  expect_failures = [aws_lambda_event_source_mapping.lambda_dynamodb_trigger]
}
