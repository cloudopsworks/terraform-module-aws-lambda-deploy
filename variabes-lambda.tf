##
# (c) 2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#

variable "lambda" {
  description = "Lambda function configuration"
  type        = any
  default     = {}
}

variable "namespace" {
  description = "Namespace for the resources"
  type        = string
}

variable "repository_owner" {
  description = "Owner of the repository"
  type        = string
}

variable "release" {
  description = "Release configuration"
  type        = any
}

variable "absolute_path" {
  description = "Absolute path to the lambda function"
  type        = string
  default     = "./"
}