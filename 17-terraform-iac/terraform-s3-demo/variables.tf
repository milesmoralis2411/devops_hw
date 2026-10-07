variable "aws_region" {
  description = "AWS region to create the bucket in"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name, used as the bucket name prefix"
  type        = string
  default     = "devops-hw"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "project_name must be 3-30 chars of lowercase letters, digits and hyphens (S3 naming rules)."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner tag applied to every resource"
  type        = string
  default     = "student"
}

variable "enable_versioning" {
  description = "Keep previous versions of every object"
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Delete old object versions after this many days"
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket (handy for demos, dangerous in prod)"
  type        = bool
  default     = true
}

variable "enable_lifecycle_rules" {
  description = "Create the lifecycle rules. Set false only for LocalStack 3.x, whose S3 API cannot satisfy the provider's post-create consistency check for lifecycle configuration."
  type        = bool
  default     = true
}
