##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "default_lambda_function" {
  count              = try(var.lambda.iam.enabled, false) ? 0 : 1
  name               = "${var.release.name}-${var.namespace}-default-role"
  path               = "/${lower(var.org.organization_name)}-${lower(var.org.organization_unit)}/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge({
    Namespace = var.namespace
    },
    local.all_tags
  )
  lifecycle {
    create_before_destroy = true
  }
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
data "aws_iam_policy_document" "lambda_function_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.namespace}/${var.release.name}*"]
  }
}


resource "aws_iam_policy" "lambda_function_logs" {
  name        = "${var.release.name}-${var.namespace}-logs-policy"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_function_logs.json

  tags = merge({
    Namespace = var.namespace
    },
    local.all_tags
  )
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "lambda_function_logs" {
  count      = try(var.lambda.iam.enabled, false) ? 0 : 1
  role       = aws_iam_role.default_lambda_function[0].name
  policy_arn = aws_iam_policy.lambda_function_logs.arn
}
