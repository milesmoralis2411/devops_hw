# PROVIDER: the plugin that translates Terraform resources into AWS API calls.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Session     = "19-cloud-terraform-in-action"
    }
  }
}
