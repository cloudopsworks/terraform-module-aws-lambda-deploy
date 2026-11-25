##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  scheduler_single_enabled  = coalesce(try(var.lambda.schedule.enabled, null), false)
  scheduler_multiple_count  = try(length(var.lambda.schedule.multiple), 0)
  scheduler_enabled         = local.scheduler_single_enabled || local.scheduler_multiple_count > 0
  scheduler_requested_group = try(var.lambda.schedule.schedule_group, null)
  scheduler_owns_group      = local.scheduler_requested_group == null || local.scheduler_requested_group == ""
  scheduler_group_name      = local.scheduler_owns_group ? one(aws_scheduler_schedule_group.environ[*].name) : local.scheduler_requested_group
}

resource "aws_scheduler_schedule_group" "environ" {
  count = local.scheduler_enabled && local.scheduler_owns_group ? 1 : 0
  name  = format("sched-grp-%s-%s", var.release.name, var.namespace)

  tags = merge({
    Namespace = var.namespace
    },
    local.all_tags
  )
}

resource "aws_scheduler_schedule" "lambda_function" {
  count       = local.scheduler_single_enabled ? 1 : 0
  name        = format("sched-%s-%s", var.release.name, var.namespace)
  group_name  = local.scheduler_group_name
  description = format("Schedule for %s:%s System: %s", var.release.name, var.namespace, local.system_name)
  flexible_time_window {
    mode                      = try(var.lambda.schedule.flexible.enabled, false) ? "FLEXIBLE" : "OFF"
    maximum_window_in_minutes = try(var.lambda.schedule.flexible.enabled, false) ? try(var.lambda.schedule.flexible.maxWindow, 60) : null
  }

  schedule_expression          = var.lambda.schedule.expression
  schedule_expression_timezone = try(var.lambda.schedule.timezone, "UTC")
  state                        = try(var.lambda.schedule.suspended, false) ? "DISABLED" : "ENABLED"

  target {
    arn      = aws_lambda_function.lambda_function.qualified_arn
    role_arn = aws_iam_role.lambda_exec[0].arn
    input    = try(jsonencode(var.lambda.schedule.payload), null)
  }

  depends_on = [aws_iam_role_policy.lambda_exec]
}

## Multiple schedule support
resource "aws_scheduler_schedule" "multiple_schedule" {
  for_each = {
    for item in range(local.scheduler_multiple_count) : format("sched-%s-%s-%s", var.release.name, var.namespace, item) => {
      item_nr  = item
      schedule = var.lambda.schedule.multiple[item]
    }
  }
  name        = each.key
  group_name  = local.scheduler_group_name
  description = format("Schedule for %s:%s System: %s Nr: %s", var.release.name, var.namespace, local.system_name, each.value.item_nr)
  flexible_time_window {
    mode                      = try(each.value.schedule.flexible.enabled, false) ? "FLEXIBLE" : "OFF"
    maximum_window_in_minutes = try(each.value.schedule.flexible.enabled, false) ? try(each.value.schedule.flexible.maxWindow, 60) : null
  }

  schedule_expression          = each.value.schedule.expression
  schedule_expression_timezone = try(each.value.schedule.timezone, "UTC")
  state                        = try(each.value.schedule.suspended, false) ? "DISABLED" : "ENABLED"

  target {
    arn      = aws_lambda_function.lambda_function.qualified_arn
    role_arn = aws_iam_role.lambda_exec[0].arn
    input    = try(jsonencode(each.value.schedule.payload), null)
  }

  depends_on = [aws_iam_role_policy.lambda_exec]
}
