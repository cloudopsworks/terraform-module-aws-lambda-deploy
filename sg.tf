##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_subnet" "lambda_sub" {
  count = try(var.lambda.vpc.enabled, false) ? length(var.lambda.vpc.subnets) : 0
  id    = var.lambda.vpc.subnets[count.index]
}

resource "aws_security_group" "this" {
  count  = try(var.lambda.vpc.create_security_group, false) && try(var.lambda.vpc.enabled, false) ? 1 : 0
  name   = "${var.release.name}-${var.namespace}-sg"
  vpc_id = data.aws_subnet.lambda_sub[0].vpc_id
  tags   = merge(local.release_tags, local.all_tags, {
    "Name" = "${var.release.name}-${var.namespace}-sg"
  })
}

resource "aws_security_group_rule" "egress" {
  count             = try(var.lambda.vpc.create_security_group, false) && try(var.lambda.vpc.enabled, false) ? 1 : 0
  description       = "Egress rule to allow all outbound traffic"
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.this[0].id
  to_port           = 0
  type              = "egress"
  cidr_blocks = [
    "0.0.0.0/0"
  ]
}