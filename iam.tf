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
  name               = "role-${local.system_name}"
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

    resources = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"]
  }
}


resource "aws_iam_policy" "lambda_function_logs" {
  name        = "policy-${local.system_name}"
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
  role       = aws_iam_role.default_lambda_function.name
  policy_arn = aws_iam_policy.lambda_function_logs.arn
}
