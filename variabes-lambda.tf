##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
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

variable "versions_bucket" {
  description = "S3 bucket for application versions"
  type        = string
}

variable "logs_bucket" {
  description = "S3 bucket for application logs"
  type        = string
  default     = ""
}

variable "bucket_path" {
  description = "Path to the S3 bucket"
  type        = string
  default     = ""
}