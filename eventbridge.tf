##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#

resource "aws_scheduler_schedule_group" "environ" {
  count = (try(var.lambda.schedule.enabled, false) || length(try(var.lambda.schedule.multiple, [])) > 0) && try(var.lambda.schedule.schedule_group, "") == "" ? 1 : 0
  name  = format("sched-grp-%s-%s", var.release.name, var.namespace)

  tags = merge({
    Namespace = var.namespace
    },
    local.all_tags
  )
}

resource "aws_scheduler_schedule" "lambda_function" {
  count       = try(var.lambda.schedule.enabled, false) ? 1 : 0
  name        = format("sched-%s-%s", var.release.name, var.namespace)
  group_name  = try(var.lambda.schedule.schedule_group, aws_scheduler_schedule_group.environ[0].name, "default")
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
    input    = try(jsonencode(var.lambda.schedule.payload), var.lambda.schedule.payload, null)
  }
}

## Multiple schedule support
resource "aws_scheduler_schedule" "multiple_schedule" {
  for_each = {
    for item in range(length(try(var.lambda.schedule.multiple, []))) : format("sched-%s-%s-%s", var.release.name, var.namespace, item) => {
      item_nr  = item
      schedule = var.lambda.schedule.multiple[item]
    }
  }
  name        = each.key
  group_name  = try(var.lambda.schedule.schedule_group, aws_scheduler_schedule_group.environ[0].name, "default")
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
    input    = try(jsonencode(each.value.schedule.payload), each.value.schedule.payload, null)
  }
}