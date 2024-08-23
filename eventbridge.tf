##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
resource "aws_scheduler_schedule_group" "environ" {
  count = try(var.lambda.schedule.enabled, false) ? 1 : 0
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
  group_name  = aws_scheduler_schedule_group.environ[0].name
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
  }
}

