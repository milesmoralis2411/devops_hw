# Evidence — Terraform S3 demo

Full workflow executed 2026-10-07 with Terraform v1.16.5, hashicorp/aws v5.100.0, against LocalStack 3.8.1 (local AWS API emulator). Output is verbatim.

## Environment
```text
$ terraform version
Terraform v1.16.5
on windows_amd64
+ provider registry.terraform.io/hashicorp/aws v5.100.0
+ provider registry.terraform.io/hashicorp/random v3.9.1

$ curl -s localhost:4566/_localstack/health | python -m json.tool | grep -E 'version|"(s3|sts|iam)"'
        "iam": "available",
        "s3": "available",
        "sts": "available",
    "version": "3.8.1"

# override.tf (git-ignored) points the AWS provider at LocalStack:
$ grep -E 'endpoints|s3 |sts |iam ' override.tf
  endpoints {
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
    iam = "http://localhost:4566"

# lifecycle rules are switched off for this emulator run only:
$ echo TF_VAR_enable_lifecycle_rules=$TF_VAR_enable_lifecycle_rules
TF_VAR_enable_lifecycle_rules=false

```

## terraform init
```text
$ terraform init
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Reusing previous version of hashicorp/random from the dependency lock file
- Using hashicorp/aws v5.100.0 from the shared cache directory
- Using hashicorp/random v3.9.1 from the shared cache directory

Terraform has been successfully initialized!

```

## terraform fmt
```text
$ terraform fmt -check -diff

$ terraform fmt

$ terraform fmt -check

```

## terraform validate
```text
$ terraform validate
Success! The configuration is valid.


```

## terraform plan
```text
$ terraform plan -out=s3.tfplan

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # data.aws_iam_policy_document.tls_only will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "tls_only" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:*",
            ]
          + effect    = "Deny"
          + resources = [
              + (known after apply),
              + (known after apply),
            ]
          + sid       = "DenyInsecureTransport"

          + condition {
              + test     = "Bool"
              + values   = [
                  + "false",
                ]
              + variable = "aws:SecureTransport"
            }

          + principals {
              + identifiers = [
                  + "*",
                ]
              + type        = "*"
            }
        }
    }

  # aws_s3_bucket.demo will be created
  + resource "aws_s3_bucket" "demo" {
      + acceleration_status         = (known after apply)
      + acl                         = (known after apply)
      + arn                         = (known after apply)
      + bucket                      = (known after apply)
      + bucket_domain_name          = (known after apply)
      + bucket_prefix               = (known after apply)
      + bucket_regional_domain_name = (known after apply)
      + force_destroy               = true
      + hosted_zone_id              = (known after apply)
      + id                          = (known after apply)
      + object_lock_enabled         = (known after apply)
      + policy                      = (known after apply)
      + region                      = (known after apply)
      + request_payer               = (known after apply)
      + tags                        = (known after apply)
      + tags_all                    = (known after apply)
      + website_domain              = (known after apply)
      + website_endpoint            = (known after apply)

      + cors_rule (known after apply)

      + grant (known after apply)

      + lifecycle_rule (known after apply)

      + logging (known after apply)

      + object_lock_configuration (known after apply)

      + replication_configuration (known after apply)

      + server_side_encryption_configuration (known after apply)

      + versioning (known after apply)

      + website (known after apply)
    }

  # aws_s3_bucket_ownership_controls.demo will be created
  + resource "aws_s3_bucket_ownership_controls" "demo" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + rule {
          + object_ownership = "BucketOwnerEnforced"
        }
    }

  # aws_s3_bucket_policy.tls_only will be created
  + resource "aws_s3_bucket_policy" "tls_only" {
      + bucket = (known after apply)
      + id     = (known after apply)
      + policy = (known after apply)
    }

  # aws_s3_bucket_public_access_block.demo will be created
  + resource "aws_s3_bucket_public_access_block" "demo" {
      + block_public_acls       = true
      + block_public_policy     = true
      + bucket                  = (known after apply)
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + restrict_public_buckets = true
    }

  # aws_s3_bucket_server_side_encryption_configuration.demo will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + rule {
          + bucket_key_enabled = true

          + apply_server_side_encryption_by_default {
              + sse_algorithm     = "AES256"
                # (1 unchanged attribute hidden)
            }
        }
    }

  # aws_s3_bucket_versioning.demo will be created
  + resource "aws_s3_bucket_versioning" "demo" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + versioning_configuration {
          + mfa_delete = (known after apply)
          + status     = "Enabled"
        }
    }

  # aws_s3_object.readme will be created
  + resource "aws_s3_object" "readme" {
      + acl                    = (known after apply)
      + arn                    = (known after apply)
      + bucket                 = (known after apply)
      + bucket_key_enabled     = (known after apply)
      + checksum_crc32         = (known after apply)
      + checksum_crc32c        = (known after apply)
      + checksum_crc64nvme     = (known after apply)
      + checksum_sha1          = (known after apply)
      + checksum_sha256        = (known after apply)
      + content                = (known after apply)
      + content_type           = "text/plain"
      + etag                   = (known after apply)
      + force_destroy          = false
      + id                     = (known after apply)
      + key                    = "hello.txt"
      + kms_key_id             = (known after apply)
      + server_side_encryption = (known after apply)
      + storage_class          = (known after apply)
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Owner"       = "varun-mundada"
          + "Project"     = "devops-hw-24bcs10326"
        }
      + version_id             = (known after apply)
    }

  # random_id.suffix will be created
  + resource "random_id" "suffix" {
      + b64_std     = (known after apply)
      + b64_url     = (known after apply)
      + byte_length = 4
      + dec         = (known after apply)
      + hex         = (known after apply)
      + id          = (known after apply)
    }

Plan: 8 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_arn         = (known after apply)
  + bucket_domain_name = (known after apply)
  + bucket_name        = (known after apply)
  + bucket_region      = (known after apply)
  + sample_object_uri  = (known after apply)
  + versioning_status  = "Enabled"

```

## terraform apply
```text
$ terraform apply -auto-approve s3.tfplan
random_id.suffix: Creating...
random_id.suffix: Creation complete after 0s [id=I8oaqg]
aws_s3_bucket.demo: Creating...
aws_s3_bucket.demo: Creation complete after 0s [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_public_access_block.demo: Creating...
aws_s3_bucket_ownership_controls.demo: Creating...
data.aws_iam_policy_document.tls_only: Reading...
aws_s3_bucket_versioning.demo: Creating...
aws_s3_bucket_server_side_encryption_configuration.demo: Creating...
aws_s3_object.readme: Creating...
data.aws_iam_policy_document.tls_only: Read complete after 0s [id=1534697149]
aws_s3_bucket_public_access_block.demo: Creation complete after 0s [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_policy.tls_only: Creating...
aws_s3_bucket_server_side_encryption_configuration.demo: Creation complete after 0s [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_object.readme: Creation complete after 0s [id=hello.txt]
aws_s3_bucket_ownership_controls.demo: Creation complete after 0s [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_policy.tls_only: Creation complete after 0s [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_versioning.demo: Creation complete after 2s [id=devops-hw-24bcs10326-dev-23ca1aaa]

Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

bucket_arn = "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa"
bucket_domain_name = "devops-hw-24bcs10326-dev-23ca1aaa.s3.ap-south-1.amazonaws.com"
bucket_name = "devops-hw-24bcs10326-dev-23ca1aaa"
bucket_region = "ap-south-1"
sample_object_uri = "s3://devops-hw-24bcs10326-dev-23ca1aaa/hello.txt"
versioning_status = "Enabled"

```

## terraform show
```text
$ terraform show | head -80
# data.aws_iam_policy_document.tls_only:
data "aws_iam_policy_document" "tls_only" {
    id            = "1534697149"
    json          = jsonencode(
        {
            Statement = [
                {
                    Action    = "s3:*"
                    Condition = {
                        Bool = {
                            "aws:SecureTransport" = "false"
                        }
                    }
                    Effect    = "Deny"
                    Principal = "*"
                    Resource  = [
                        "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/*",
                        "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa",
                    ]
                    Sid       = "DenyInsecureTransport"
                },
            ]
            Version   = "2012-10-17"
        }
    )
    minified_json = jsonencode(
        {
            Statement = [
                {
                    Action    = "s3:*"
                    Condition = {
                        Bool = {
                            "aws:SecureTransport" = "false"
                        }
                    }
                    Effect    = "Deny"
                    Principal = "*"
                    Resource  = [
                        "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/*",
                        "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa",
                    ]
                    Sid       = "DenyInsecureTransport"
                },
            ]
            Version   = "2012-10-17"
        }
    )
    version       = "2012-10-17"

    statement {
        actions       = [
            "s3:*",
        ]
        effect        = "Deny"
        not_actions   = []
        not_resources = []
        resources     = [
            "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa",
            "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/*",
        ]
        sid           = "DenyInsecureTransport"

        condition {
            test     = "Bool"
            values   = [
                "false",
            ]
            variable = "aws:SecureTransport"
        }

        principals {
            identifiers = [
                "*",
            ]
            type        = "*"
        }
    }
}

# aws_s3_bucket.demo:

$ terraform state list
data.aws_iam_policy_document.tls_only
aws_s3_bucket.demo
aws_s3_bucket_ownership_controls.demo
aws_s3_bucket_policy.tls_only
aws_s3_bucket_public_access_block.demo
aws_s3_bucket_server_side_encryption_configuration.demo
aws_s3_bucket_versioning.demo
aws_s3_object.readme
random_id.suffix

```

## terraform output
```text
$ terraform output
bucket_arn = "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa"
bucket_domain_name = "devops-hw-24bcs10326-dev-23ca1aaa.s3.ap-south-1.amazonaws.com"
bucket_name = "devops-hw-24bcs10326-dev-23ca1aaa"
bucket_region = "ap-south-1"
sample_object_uri = "s3://devops-hw-24bcs10326-dev-23ca1aaa/hello.txt"
versioning_status = "Enabled"

$ terraform output -raw bucket_name
devops-hw-24bcs10326-dev-23ca1aaa

$ terraform output -json
{
  "bucket_arn": {
    "sensitive": false,
    "type": "string",
    "value": "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa"
  },
  "bucket_domain_name": {
    "sensitive": false,
    "type": "string",
    "value": "devops-hw-24bcs10326-dev-23ca1aaa.s3.ap-south-1.amazonaws.com"
  },
  "bucket_name": {
    "sensitive": false,
    "type": "string",
    "value": "devops-hw-24bcs10326-dev-23ca1aaa"
  },
  "bucket_region": {
    "sensitive": false,
    "type": "string",
    "value": "ap-south-1"
  },
  "sample_object_uri": {
    "sensitive": false,
    "type": "string",
    "value": "s3://devops-hw-24bcs10326-dev-23ca1aaa/hello.txt"
  },
  "versioning_status": {
    "sensitive": false,
    "type": "string",
    "value": "Enabled"
  }
}

```

## Verify the bucket really exists (AWS CLI inside LocalStack)
```text
$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3 ls
2026-10-07 15:56:44 devops-hw-24bcs10326-dev-23ca1aaa

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3 ls s3://devops-hw-24bcs10326-dev-23ca1aaa/
2026-10-07 15:56:44         78 hello.txt

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3 cp s3://devops-hw-24bcs10326-dev-23ca1aaa/hello.txt -
Hello from Terraform! Bucket devops-hw-24bcs10326-dev-23ca1aaa in ap-south-1.

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3api get-bucket-versioning --bucket devops-hw-24bcs10326-dev-23ca1aaa
{
    "Status": "Enabled"
}

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3api get-bucket-encryption --bucket devops-hw-24bcs10326-dev-23ca1aaa
{
    "ServerSideEncryptionConfiguration": {
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }
}

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3api get-public-access-block --bucket devops-hw-24bcs10326-dev-23ca1aaa
{
    "PublicAccessBlockConfiguration": {
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }
}

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3api get-bucket-policy --bucket devops-hw-24bcs10326-dev-23ca1aaa --query Policy --output text | python -m json.tool
{
    "Statement": [
        {
            "Action": "s3:*",
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            },
            "Effect": "Deny",
            "Principal": "*",
            "Resource": [
                "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/*",
                "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa"
            ],
            "Sid": "DenyInsecureTransport"
        }
    ],
    "Version": "2012-10-17"
}

```

## Change detection - edit a variable, plan shows an in-place update
```text
$ terraform plan -var force_destroy=false | grep -E '~|force_destroy|Plan:'
  ~ update in-place
  ~ resource "aws_s3_bucket" "demo" {
      ~ force_destroy               = true -> false
  ~ resource "aws_s3_bucket_policy" "tls_only" {
      ~ policy = jsonencode(
Plan: 0 to add, 2 to change, 0 to destroy.

```

## terraform destroy
```text
$ terraform destroy -auto-approve
random_id.suffix: Refreshing state... [id=I8oaqg]
aws_s3_bucket.demo: Refreshing state... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_versioning.demo: Refreshing state... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_public_access_block.demo: Refreshing state... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_server_side_encryption_configuration.demo: Refreshing state... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_ownership_controls.demo: Refreshing state... [id=devops-hw-24bcs10326-dev-23ca1aaa]
data.aws_iam_policy_document.tls_only: Reading...
aws_s3_object.readme: Refreshing state... [id=hello.txt]
data.aws_iam_policy_document.tls_only: Read complete after 0s [id=1534697149]
aws_s3_bucket_policy.tls_only: Refreshing state... [id=devops-hw-24bcs10326-dev-23ca1aaa]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # aws_s3_bucket.demo will be destroyed
  - resource "aws_s3_bucket" "demo" {
      - arn                         = "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - bucket                      = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - bucket_domain_name          = "devops-hw-24bcs10326-dev-23ca1aaa.s3.amazonaws.com" -> null
      - bucket_regional_domain_name = "devops-hw-24bcs10326-dev-23ca1aaa.s3.ap-south-1.amazonaws.com" -> null
      - force_destroy               = true -> null
      - hosted_zone_id              = "Z11RGJOFQNVJUP" -> null
      - id                          = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - object_lock_enabled         = false -> null
      - policy                      = jsonencode(
            {
              - Statement = [
                  - {
                      - Action    = "s3:*"
                      - Condition = {
                          - Bool = {
                              - "aws:SecureTransport" = "false"
                            }
                        }
                      - Effect    = "Deny"
                      - Principal = "*"
                      - Resource  = [
                          - "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/*",
                          - "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa",
                        ]
                      - Sid       = "DenyInsecureTransport"
                    },
                ]
              - Version   = "2012-10-17"
            }
        ) -> null
      - region                      = "ap-south-1" -> null
      - request_payer               = "BucketOwner" -> null
      - tags                        = {
          - "Name" = "devops-hw-24bcs10326-dev-23ca1aaa"
        } -> null
      - tags_all                    = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "devops-hw-24bcs10326-dev-23ca1aaa"
          - "Owner"       = "varun-mundada"
          - "Project"     = "devops-hw-24bcs10326"
        } -> null
        # (2 unchanged attributes hidden)

      - grant {
          - id          = "75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a" -> null
          - permissions = [
              - "FULL_CONTROL",
            ] -> null
          - type        = "CanonicalUser" -> null
            # (1 unchanged attribute hidden)
        }

      - server_side_encryption_configuration {
          - rule {
              - bucket_key_enabled = true -> null

              - apply_server_side_encryption_by_default {
                  - sse_algorithm     = "AES256" -> null
                    # (1 unchanged attribute hidden)
                }
            }
        }

      - versioning {
          - enabled    = true -> null
          - mfa_delete = false -> null
        }
    }

  # aws_s3_bucket_ownership_controls.demo will be destroyed
  - resource "aws_s3_bucket_ownership_controls" "demo" {
      - bucket = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - id     = "devops-hw-24bcs10326-dev-23ca1aaa" -> null

      - rule {
          - object_ownership = "BucketOwnerEnforced" -> null
        }
    }

  # aws_s3_bucket_policy.tls_only will be destroyed
  - resource "aws_s3_bucket_policy" "tls_only" {
      - bucket = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - id     = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - policy = jsonencode(
            {
              - Statement = [
                  - {
                      - Action    = "s3:*"
                      - Condition = {
                          - Bool = {
                              - "aws:SecureTransport" = "false"
                            }
                        }
                      - Effect    = "Deny"
                      - Principal = "*"
                      - Resource  = [
                          - "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/*",
                          - "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa",
                        ]
                      - Sid       = "DenyInsecureTransport"
                    },
                ]
              - Version   = "2012-10-17"
            }
        ) -> null
    }

  # aws_s3_bucket_public_access_block.demo will be destroyed
  - resource "aws_s3_bucket_public_access_block" "demo" {
      - block_public_acls       = true -> null
      - block_public_policy     = true -> null
      - bucket                  = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - id                      = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - ignore_public_acls      = true -> null
      - restrict_public_buckets = true -> null
    }

  # aws_s3_bucket_server_side_encryption_configuration.demo will be destroyed
  - resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
      - bucket                = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - id                    = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
        # (1 unchanged attribute hidden)

      - rule {
          - bucket_key_enabled = true -> null

          - apply_server_side_encryption_by_default {
              - sse_algorithm     = "AES256" -> null
                # (1 unchanged attribute hidden)
            }
        }
    }

  # aws_s3_bucket_versioning.demo will be destroyed
  - resource "aws_s3_bucket_versioning" "demo" {
      - bucket                = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - id                    = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
        # (1 unchanged attribute hidden)

      - versioning_configuration {
          - status     = "Enabled" -> null
            # (1 unchanged attribute hidden)
        }
    }

  # aws_s3_object.readme will be destroyed
  - resource "aws_s3_object" "readme" {
      - arn                           = "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa/hello.txt" -> null
      - bucket                        = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
      - bucket_key_enabled            = false -> null
      - content                       = <<-EOT
            Hello from Terraform! Bucket devops-hw-24bcs10326-dev-23ca1aaa in ap-south-1.
        EOT -> null
      - content_type                  = "text/plain" -> null
      - etag                          = "511757bba62f37519bcc863cae100a58" -> null
      - force_destroy                 = false -> null
      - id                            = "hello.txt" -> null
      - key                           = "hello.txt" -> null
      - metadata                      = {} -> null
      - server_side_encryption        = "AES256" -> null
      - storage_class                 = "STANDARD" -> null
      - tags                          = {} -> null
      - tags_all                      = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Owner"       = "varun-mundada"
          - "Project"     = "devops-hw-24bcs10326"
        } -> null
      - version_id                    = "3D35.s2DkuWYEamiHanVeMHsub3u_pXx" -> null
        # (13 unchanged attributes hidden)
    }

  # random_id.suffix will be destroyed
  - resource "random_id" "suffix" {
      - b64_std     = "I8oaqg==" -> null
      - b64_url     = "I8oaqg" -> null
      - byte_length = 4 -> null
      - dec         = "600447658" -> null
      - hex         = "23ca1aaa" -> null
      - id          = "I8oaqg" -> null
    }

Plan: 0 to add, 0 to change, 8 to destroy.

Changes to Outputs:
  - bucket_arn         = "arn:aws:s3:::devops-hw-24bcs10326-dev-23ca1aaa" -> null
  - bucket_domain_name = "devops-hw-24bcs10326-dev-23ca1aaa.s3.ap-south-1.amazonaws.com" -> null
  - bucket_name        = "devops-hw-24bcs10326-dev-23ca1aaa" -> null
  - bucket_region      = "ap-south-1" -> null
  - sample_object_uri  = "s3://devops-hw-24bcs10326-dev-23ca1aaa/hello.txt" -> null
  - versioning_status  = "Enabled" -> null
aws_s3_bucket_versioning.demo: Destroying... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_policy.tls_only: Destroying... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_ownership_controls.demo: Destroying... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_object.readme: Destroying... [id=hello.txt]
aws_s3_bucket_server_side_encryption_configuration.demo: Destroying... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket_versioning.demo: Destruction complete after 0s
aws_s3_bucket_server_side_encryption_configuration.demo: Destruction complete after 0s
aws_s3_bucket_ownership_controls.demo: Destruction complete after 0s
aws_s3_bucket_policy.tls_only: Destruction complete after 0s
aws_s3_bucket_public_access_block.demo: Destroying... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_object.readme: Destruction complete after 0s
aws_s3_bucket_public_access_block.demo: Destruction complete after 0s
aws_s3_bucket.demo: Destroying... [id=devops-hw-24bcs10326-dev-23ca1aaa]
aws_s3_bucket.demo: Destruction complete after 0s
random_id.suffix: Destroying... [id=I8oaqg]
random_id.suffix: Destruction complete after 0s

Destroy complete! Resources: 8 destroyed.

$ terraform state list

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3 ls

```
