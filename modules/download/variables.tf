##
# (c) 2022-2024 - Cloud Ops Works LLC - https://cloudops.works/
#            On GitHub: https://github.com/cloudopsworks
#            Distributed Under Apache v2.0 License
#
variable "release_name" {
  type = string
}

variable "source_name" {
  type = string
}

variable "source_version" {
  type = string
}

variable "namespace" {
  type        = string
  description = "(required) namespace that determines the environment naming"
}

variable "repository_url" {
  type        = string
  default     = "https://github.com"
  description = "(optional) repository url to pull releases."
}

variable "repository_owner" {
  type        = string
  description = "(required) Repository onwer/team"
}

variable "force_source_compressed" {
  type        = bool
  default     = false
  description = "(Optional) Forces that source file should be downloaded as zip file or tar file"
}

variable "source_compressed_type" {
  type        = string
  default     = "zip"
  description = "(Optional) Indicates the type of the source package to proceed with its de-compression."
  validation {
    condition     = can(regex("(?i:zip|tar|tar.gz|tgz|tar.bz|tar.bz2|tbz|tbz2|tar.z)", var.source_compressed_type))
    error_message = "Error, file types should be one of: zip, tar, tar.gz, tgz, tar.bz, tar.bz2, tar.z or tar.Z, please set the correct type."
  }
}

variable "bluegreen_identifier" {
  type        = string
  default     = ""
  description = "(optional) Identifier for generating names specific for Blue/Green deployments"
  nullable    = false
}

variable "config_source_folder" {
  type        = string
  description = "(required) Location [root relative] of the configuration source."
}

# variable "config_hash_file" {
#   type        = string
#   description = "(required) Hashfile location to track source "
# }

variable "extra_tags" {
  type        = map(string)
  description = "(optional) Extra tags to be added to the resources"
  default     = {}
}

variable "github_package" {
  type        = bool
  description = "(optional) Indicates if the source is a github package"
  default     = false
}

variable "package_name" {
  type        = string
  description = "(optional) Name of the package."
  default     = ""
}

variable "package_type" {
  type        = string
  description = "(optional) Type of the package from github (MAVEN,NPM,DOCKER,NET)"
  default     = ""
}

variable "absolute_path" {
  type        = string
  description = "(optional) Absolute path to the lambda function"
  default     = ""
}