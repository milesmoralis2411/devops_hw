variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type    = string
  default = "yatri"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "node_min" {
  type    = number
  default = 2
}

variable "node_max" {
  type    = number
  default = 4
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the EKS API publicly (e.g. an office/VPN range). Empty = private endpoint only"
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Do not expose the EKS API to the whole internet; list specific CIDRs."
  }
}

variable "github_repository" {
  description = "owner/repo allowed to assume the CI role via OIDC"
  type        = string
  default     = "milesmoralis2411/devops_hw"
}
