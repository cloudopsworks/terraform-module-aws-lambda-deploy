##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

# lambda: # (Required) AWS Lambda function configuration.
#   handler: "index.handler"          # (Required) Function entrypoint in your code, e.g. "index.handler" (Node.js/Python) or "com.example.App::handleRequest" (Java).
#   runtime: "nodejs22.x"             # (Required) Lambda runtime identifier. Valid values include: nodejs18.x, nodejs20.x, nodejs22.x, python3.10, python3.11, python3.12, python3.13, java17, java21, dotnet8, ruby3.3, provided.al2023.
#   memory_size: 128                  # (Optional) Amount of memory in MB. Valid range 128-10240, in 1 MB increments. Default: 128
#   timeout: 3                        # (Optional) Execution timeout in seconds. Valid range 1-900. Default: 3
#   reserved_concurrency: -1          # (Optional) Reserved concurrent executions. Use -1 for unreserved (account pool). Default: -1
#   provisioned_concurrency: 0        # (Optional) Provisioned concurrent executions applied to the published version. Set > 0 to enable. Default: 0 (disabled)
#   log_retention_days: 14            # (Optional) CloudWatch log group retention in days. Valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0 (never expire). Default: 14
#
#   environment:                      # (Required) Environment variables passed to the function. Use an empty list to declare none.
#     variables:                      # (Required) List of name/value pairs.
#       - name: "LOG_LEVEL"           # (Required) Environment variable name.
#         value: "INFO"               # (Required) Environment variable value.
#
#   functionUrls: []                  # (Required) List of Lambda Function URL endpoints. Use an empty list to create none.
#     - id: "prod"                    # (Required) Unique key for the endpoint within this module.
#       qualifier: "prod"             # (Required) Alias or version to expose. Use an empty string to target the unpublished "$LATEST".
#       authorization_type: "AWS_IAM" # (Required) Authorization model. Valid values: AWS_IAM, NONE. An empty string resolves to NONE.
#       cors:                         # (Required) CORS configuration block. Use an empty map {} to accept the defaults below.
#         allowCredentials: false     # (Optional) Allow cookies/credentials in cross-origin requests. Default: false
#         allowMethods: []            # (Optional) Allowed HTTP methods, e.g. ["GET", "POST"] or ["*"]. Default: []
#         allowOrigins: []            # (Optional) Allowed origins, e.g. ["https://example.com"] or ["*"]. Default: []
#         allowHeaders: []            # (Optional) Allowed request headers. Default: []
#         exposeHeaders: []           # (Optional) Response headers exposed to the browser. Default: []
#         maxAge: 600                 # (Optional) Preflight cache duration in seconds. Valid range 0-86400. Default: 600
#
#   alias:                            # (Optional) Lambda alias pointing at the version published by this module. Default: disabled
#     enabled: true                   # (Optional) Create the alias. Default: false
#     name: "prod"                    # (Required when enabled) Alias name, e.g. prod | uat | dev | demo.
#     routing_config:                 # (Optional) Weighted routing to a second version. Default: [] (all traffic to the published version)
#       - version: "1"                # (Required) Additional Lambda version to receive traffic.
#         weight: 0.1                 # (Required) Fraction of traffic for that version. Valid range 0.0-1.0.
#
#   layers: []                        # (Optional) Lambda layers to attach. Default: []
#     - arn: "arn:aws:lambda:us-east-1:123456789012:layer:my-layer:1" # (Required) Fully qualified layer version ARN.
#
#   vpc:                              # (Optional) VPC attachment for the function. Default: disabled
#     enabled: false                  # (Optional) Attach the function to a VPC. Default: false
#     subnets: []                     # (Required when enabled) Subnet IDs the ENIs are created in, e.g. ["subnet-0abc...", "subnet-0def..."].
#     create_security_group: false    # (Optional) Create a managed security group allowing all egress. Default: false
#     security_groups: []             # (Required when enabled and create_security_group is false) Existing security group IDs, e.g. ["sg-0abc..."].
#
#   logging:                          # (Optional) Advanced CloudWatch logging configuration.
#     log_format: "JSON"              # (Optional) Log output format. Valid values: JSON, Text. Default: JSON
#     application_log_level: "INFO"   # (Optional) Minimum level for application logs, only honored when log_format is JSON. Valid values: TRACE, DEBUG, INFO, WARN, ERROR, FATAL. Default: null (AWS default)
#     system_log_level: "INFO"        # (Optional) Minimum level for Lambda system logs, only honored when log_format is JSON. Valid values: DEBUG, INFO, WARN. Default: null (AWS default)
#
#   tracing:                          # (Optional) AWS X-Ray tracing. Default: disabled
#     enabled: true                   # (Optional) Enable X-Ray tracing. Default: false
#     mode: "Active"                  # (Required when enabled) Sampling mode. Valid values: Active, PassThrough.
#
#   ephemeral_storage:                # (Optional) Size of the function's /tmp directory. Default: disabled (AWS default of 512 MB)
#     enabled: true                   # (Optional) Override the default ephemeral storage size. Default: false
#     size: 1024                      # (Optional) Size in MB. Valid range 512-10240. Default: 512
#
#   efs:                              # (Optional) Amazon EFS mount for the function. Requires vpc.enabled = true. Default: disabled
#     enabled: true                   # (Optional) Mount an EFS access point. Default: false
#     arn: "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-0abc" # (Required when enabled) EFS access point ARN.
#     local_mount_path: "/mnt/efs"    # (Required when enabled) Mount path inside the function, must start with /mnt/.
#
#   iam:                              # (Optional) IAM configuration. When disabled, a default execution role with CloudWatch Logs access is created.
#     enabled: true                   # (Optional) Create a dedicated function role instead of the default role. Default: false
#     policy_attachments:             # (Optional) Managed policies attached to the function role. Only applied when iam.enabled is true. Default: []
#       - arn: "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess" # (Required) Managed policy ARN.
#     statements:                     # (Optional) Inline policy statements added to the function role. Only applied when iam.enabled is true. Default: []
#       - effect: "Allow"             # (Required) Statement effect. Valid values: Allow, Deny.
#         action:                     # (Required) List of IAM actions, e.g. ["s3:GetObject"].
#           - "s3:GetObject"
#         resource:                   # (Required) List of resource ARNs, e.g. ["arn:aws:s3:::my-bucket/*"] or ["*"].
#           - "arn:aws:s3:::my-bucket/*"
#     execRole:                       # (Optional) Separate invoker role granting lambda:InvokeFunction on this function. Required for schedules. Default: disabled
#       enabled: true                 # (Optional) Create the invoker role. Default: false
#       principals:                   # (Optional) Service principals allowed to assume the role. "scheduler.amazonaws.com" is appended automatically when a schedule is configured. Default: ["lambda.amazonaws.com"]
#         - "lambda.amazonaws.com"
#         - "apigateway.amazonaws.com"
#
#   schedule:                         # (Optional) EventBridge Scheduler configuration. Requires iam.execRole.enabled = true. Default: disabled
#     enabled: false                  # (Optional) Create a single schedule. Mutually exclusive with schedule.multiple. Default: false
#     schedule_group: ""              # (Optional) Name of an existing schedule group. When empty, a dedicated group is created for this function. Default: "" (create a group)
#     expression: "rate(1 hour)"      # (Required when enabled) Schedule expression, e.g. "rate(1 hour)", "cron(0 10 * * ? *)", or "at(2026-01-01T00:00:00)".
#     timezone: "UTC"                 # (Optional) IANA timezone or UTC offset for the expression, e.g. "America/Bogota". Default: "UTC"
#     suspended: false                # (Optional) Create the schedule in DISABLED state. Default: false
#     payload: {}                     # (Optional) Event payload delivered to the function. Accepts a YAML/JSON object (encoded to JSON) or a raw string. Default: null
#     flexible:                       # (Optional) Flexible time window for the invocation. Default: disabled (mode OFF)
#       enabled: true                 # (Optional) Enable the flexible window. Default: false
#       maxWindow: 20                 # (Optional) Window size in minutes. Valid range 1-1440. Default: 60
#     multiple: []                    # (Optional) Several schedules for the same function. Used instead of schedule.enabled. Default: []
#       - expression: "cron(0 10 * * ? *)" # (Required) Schedule expression for this entry.
#         timezone: "UTC"             # (Optional) IANA timezone or UTC offset. Default: "UTC"
#         suspended: false            # (Optional) Create this schedule in DISABLED state. Default: false
#         payload: {}                 # (Optional) Event payload for this entry. Default: null
#         flexible:                   # (Optional) Flexible time window for this entry. Default: disabled
#           enabled: true             # (Optional) Enable the flexible window. Default: false
#           maxWindow: 20             # (Optional) Window size in minutes. Default: 60
#
#   triggers:                         # (Optional) Event sources invoking the function. Default: {} (no triggers)
#     s3:                             # (Optional) S3 bucket notification trigger on an existing bucket.
#       bucketName: "my-bucket"       # (Required) Name of an existing S3 bucket. An empty string disables the trigger.
#       events:                       # (Required) S3 event types, e.g. ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"].
#         - "s3:ObjectCreated:*"
#       filterPrefix: "incoming/"     # (Required) Key prefix filter. Use an empty string for no prefix filter.
#       filterSuffix: ".json"         # (Required) Key suffix filter. Use an empty string for no suffix filter.
#     sqs:                            # (Optional) SQS event source mapping on an existing queue.
#       queueName: "my-queue"         # (Required) Name of an existing SQS queue. An empty string disables the trigger.
#       batchSize: 10                 # (Optional) Records per batch. Valid range 1-10000 (max 10 for FIFO queues). Default: null (AWS default of 10)
#       maximumConcurrency: 2         # (Optional) Maximum concurrent invocations for this source. Only applied when >= 2. Valid range 2-1000. Default: unset
#       metricsConfig: false          # (Optional) Publish the EventCount metric for this mapping. Default: false
#       filterCriteria: []            # (Optional) Event filters. Default: [] (no filtering)
#         - pattern: '{"body":{"Location":["New York"]}}' # (Required unless pattern_object is set) Filter pattern as a raw JSON string.
#         - pattern_object:           # (Required unless pattern is set) Filter pattern as a YAML object, encoded to JSON by the module.
#             body:
#               Location:
#                 - "New York"
#     dynamodb:                       # (Optional) DynamoDB Streams event source mapping on an existing table. The table must have streams enabled.
#       tableName: "my-table"         # (Required) Name of an existing DynamoDB table. An empty string disables the trigger.
#       startingPosition: "LATEST"    # (Optional) Stream position to read from. Valid values: LATEST, TRIM_HORIZON. Default: "LATEST"
#       batchSize: 100                # (Optional) Records per batch. Valid range 1-10000. Default: null (AWS default of 100)
#       maximumRetryAttempts: 3       # (Optional) Retries for a failed batch. Valid range -1 to 10000, where -1 means retry until the record expires. Default: null (AWS default of -1)
#       metricsConfig: false          # (Optional) Publish the EventCount metric for this mapping. Default: false
#       filterCriteria: []            # (Optional) Event filters, same structure as triggers.sqs.filterCriteria. Default: []
variable "lambda" {
  description = "(Required) AWS Lambda function configuration. Supports runtime settings, environment variables, function URLs, aliases, layers, VPC and EFS attachment, logging, X-Ray tracing, IAM roles, EventBridge schedules, and S3/SQS/DynamoDB triggers. See the inline documentation above for every supported attribute. Default: {}"
  type        = any
  default     = {}
}

# namespace: "dev" # (Required) Namespace suffix appended to the function and IAM resource names.
variable "namespace" {
  description = "(Required) Namespace appended to the Lambda function name and its IAM resources, e.g. \"dev\". Combined with release.name to form the function name \"<release.name>-<namespace>\"."
  type        = string
}

# repository_owner: "cloudopsworks" # (Required) GitHub organization owning the source repository.
variable "repository_owner" {
  description = "(Required) Owner of the source code repository, e.g. \"cloudopsworks\". Supplied by the CI/CD pipeline for traceability; reserved for future use and not currently referenced by any resource."
  type        = string
}

# release: # (Required) Release metadata for the deployed artifact.
#   name: "my-function"     # (Required) Release name, used as the base of the function, role, and policy names.
#   source:                 # (Required) Source artifact details.
#     version: "1.0.0"      # (Required) Artifact version, rendered into the function description.
variable "release" {
  description = "(Required) Release metadata for the deployed artifact. Requires release.name (base name for the function and its IAM resources) and release.source.version (artifact version shown in the function description)."
  type        = any
}

# absolute_path: "./" # (Optional) Absolute path to the lambda function sources. Default: "./"
variable "absolute_path" {
  description = "(Optional) Absolute path to the Lambda function sources on the runner. Supplied by the CI/CD pipeline; reserved for future use and not currently referenced by any resource. Default: \"./\""
  type        = string
  default     = "./"
}

# versions_bucket: "my-artifacts-bucket" # (Required) S3 bucket holding the packaged function ZIP.
variable "versions_bucket" {
  description = "(Required) Name of the S3 bucket holding the packaged application versions. The module reads the deployment ZIP from this bucket."
  type        = string
}

# logs_bucket: "" # (Optional) S3 bucket for application logs. Default: ""
variable "logs_bucket" {
  description = "(Optional) Name of the S3 bucket for application logs. Supplied by the CI/CD pipeline; reserved for future use and not currently referenced by any resource. Default: \"\""
  type        = string
  default     = ""
}

# bucket_path: "releases/my-function/1.0.0/function.zip" # (Optional) S3 key of the deployment package. Default: ""
variable "bucket_path" {
  description = "(Optional) S3 object key of the deployment package inside versions_bucket, e.g. \"releases/my-function/1.0.0/function.zip\". Default: \"\""
  type        = string
  default     = ""
}
