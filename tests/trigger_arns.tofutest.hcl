# OpenTofu materializes mocked computed ARNs during planning. Terraform skips
# this file and runs the shared trigger_contract suite instead.
mock_provider "aws" {
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
  mock_resource "aws_lambda_function" {
    defaults = {
      arn           = "arn:aws:lambda:us-east-1:123456789012:function:ingest-test"
      qualified_arn = "arn:aws:lambda:us-east-1:123456789012:function:ingest-test:1"
    }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/commerce/orders-created" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/example-platform/ingest-test-lambda-role" }
  }
}

override_resource {
  target = aws_iam_role.lambda_exec
  values = { arn = "arn:aws:iam::123456789012:role/example-platform/ingest-test-exec-role" }
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
  release          = { name = "ingest", source = { version = "1.0.0" } }
}

run "bind_to_the_correct_rule_function_and_role_arns" {
  command = plan
  variables {
    lambda = merge(jsondecode(file("tests/fixtures/lambda.json")), {
      iam = { enabled = true }
      schedule = {
        enabled    = true
        expression = "rate(1 hour)"
        multiple   = [{ expression = "rate(3 hours)" }]
      }
      triggers = {
        sns = { topicArn = "arn:aws:sns:us-east-1:123456789012:order-notifications" }
        eventbridge = {
          ruleName     = "orders-created"
          eventBusName = "commerce"
          eventPattern = { source = ["app.orders"] }
        }
        kinesis = {
          streamArn        = "arn:aws:kinesis:us-east-1:123456789012:stream/order-events"
          startingPosition = null
        }
      }
    })
  }

  assert {
    condition = (
      aws_sns_topic_subscription.lambda_function[0].endpoint == output.function_arn &&
      aws_cloudwatch_event_target.lambda_function[0].arn == output.function_arn &&
      aws_lambda_permission.allow_eventbridge[0].source_arn == "arn:aws:events:us-east-1:123456789012:rule/commerce/orders-created" &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].function_name == output.function_arn &&
      aws_lambda_event_source_mapping.lambda_kinesis_trigger[0].starting_position == "LATEST"
    )
    error_message = "SNS, EventBridge, and the Kinesis mapping must target the unqualified Lambda ARN, and only the exact EventBridge rule should get invoke permission."
  }

  assert {
    condition = alltrue([
      for schedule in concat(aws_scheduler_schedule.lambda_function, values(aws_scheduler_schedule.multiple_schedule)) :
      one(schedule.target).arn == aws_lambda_function.lambda_function.qualified_arn &&
      one(schedule.target).role_arn == output.lambda_exec_role_arn &&
      one(schedule.target).role_arn != output.lambda_function_role_arn
    ])
    error_message = "Each schedule must target the published Lambda ARN with the separate invoker role."
  }
}
