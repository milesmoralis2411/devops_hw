# Values for this demo. Nothing here is secret, so it is safe to commit.
# Credentials are NEVER placed in tfvars - they come from the AWS CLI
# profile or the AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY environment.
aws_region                         = "ap-south-1"
project_name                       = "devops-hw-24bcs10326"
environment                        = "dev"
owner                              = "varun-mundada"
enable_versioning                  = true
noncurrent_version_expiration_days = 30
force_destroy                      = true
