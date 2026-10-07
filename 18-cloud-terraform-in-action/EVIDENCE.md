# Evidence — Cloud & Terraform in Action

Full workflow executed 2026-10-07 with Terraform v1.16.5, hashicorp/aws v5.100.0, against LocalStack 3.8.1 (EC2, S3, IAM, STS APIs). Output is verbatim.

## terraform init - providers are downloaded
```text
$ terraform init
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/random from the dependency lock file
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using hashicorp/random v3.9.1 from the shared cache directory
- Using hashicorp/aws v5.100.0 from the shared cache directory

Terraform has been successfully initialized!

$ terraform providers

Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/aws] ~> 5.0
└── provider[registry.terraform.io/hashicorp/random] ~> 3.6


```

## terraform fmt + validate
```text
$ terraform fmt -recursive

$ terraform fmt -check

$ terraform validate
Success! The configuration is valid.


```

## Dependency graph
```text
# Implicit edges come from references (subnet -> vpc), the explicit
# depends_on adds instance -> s3 object. Only resource-to-resource edges shown:
$ terraform graph | grep -E '"(aws_|random_)[^"]*" -> "(aws_|random_)' | sed -E 's/\[root\] //g; s/ \(expand\)//g' | sort
  "aws_iam_instance_profile.web" -> "aws_iam_role.web";
  "aws_iam_role_policy.read_assets" -> "aws_iam_role.web";
  "aws_iam_role_policy_attachment.ssm" -> "aws_iam_role.web";
  "aws_instance.web" -> "aws_iam_instance_profile.web";
  "aws_instance.web" -> "aws_iam_role_policy.read_assets";
  "aws_instance.web" -> "aws_route_table_association.public";
  "aws_instance.web" -> "aws_s3_object.index";
  "aws_instance.web" -> "aws_security_group.web";
  "aws_internet_gateway.igw" -> "aws_vpc.main";
  "aws_route_table.public" -> "aws_internet_gateway.igw";
  "aws_route_table_association.public" -> "aws_route_table.public";
  "aws_route_table_association.public" -> "aws_subnet.public";
  "aws_s3_bucket.assets" -> "random_id.bucket_suffix";
  "aws_s3_bucket_public_access_block.assets" -> "aws_s3_bucket.assets";
  "aws_s3_bucket_server_side_encryption_configuration.assets" -> "aws_s3_bucket.assets";
  "aws_s3_bucket_versioning.assets" -> "aws_s3_bucket.assets";
  "aws_s3_object.index" -> "aws_s3_bucket.assets";
  "aws_security_group.web" -> "aws_vpc.main";
  "aws_subnet.public" -> "aws_vpc.main";
  "aws_vpc_security_group_egress_rule.all" -> "aws_security_group.web";
  "aws_vpc_security_group_ingress_rule.http" -> "aws_security_group.web";
  "aws_vpc_security_group_ingress_rule.ssh" -> "aws_security_group.web";

```

## terraform plan
```text
$ terraform plan -out=infra.tfplan
data.aws_availability_zones.available: Reading...
data.aws_iam_policy_document.ec2_assume: Reading...
data.aws_ami.al2023: Reading...
data.aws_iam_policy_document.ec2_assume: Read complete after 0s [id=2851119427]
data.aws_availability_zones.available: Read complete after 2s [id=ap-south-1]
data.aws_ami.al2023: Read complete after 2s [id=ami-089d868c1c73e3728]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # data.aws_iam_policy_document.read_assets will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "read_assets" {
      + id            = (known after apply)
      + json          = (known after apply)
      + minified_json = (known after apply)

      + statement {
          + actions   = [
              + "s3:GetObject",
            ]
          + resources = [
              + (known after apply),
            ]
          + sid       = "ReadSiteContent"
        }
      + statement {
          + actions   = [
              + "s3:ListBucket",
            ]
          + resources = [
              + (known after apply),
            ]
          + sid       = "ListBucket"
        }
    }

  # aws_iam_instance_profile.web will be created
  + resource "aws_iam_instance_profile" "web" {
      + arn         = (known after apply)
      + create_date = (known after apply)
      + id          = (known after apply)
      + name        = "yatri-dev-web-profile"
      + name_prefix = (known after apply)
      + path        = "/"
      + role        = "yatri-dev-web-role"
      + tags_all    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + unique_id   = (known after apply)
    }

  # aws_iam_role.web will be created
  + resource "aws_iam_role" "web" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "ec2.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = false
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = "yatri-dev-web-role"
      + name_prefix           = (known after apply)
      + path                  = "/"
      + tags_all              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # aws_iam_role_policy.read_assets will be created
  + resource "aws_iam_role_policy" "read_assets" {
      + id          = (known after apply)
      + name        = "read-site-assets"
      + name_prefix = (known after apply)
      + policy      = (known after apply)
      + role        = (known after apply)
    }

  # aws_iam_role_policy_attachment.ssm will be created
  + resource "aws_iam_role_policy_attachment" "ssm" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      + role       = "yatri-dev-web-role"
    }

  # aws_instance.web will be created
  + resource "aws_instance" "web" {
      + ami                                  = "ami-089d868c1c73e3728"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = "yatri-dev-web-profile"
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_lifecycle                   = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t3.micro"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = (known after apply)
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + spot_instance_request_id             = (known after apply)
      + subnet_id                            = (known after apply)
      + tags                                 = {
          + "Name" = "yatri-dev-web"
        }
      + tags_all                             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-web"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + tenancy                              = (known after apply)
      + user_data                            = (known after apply)
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = true
      + vpc_security_group_ids               = (known after apply)

      + capacity_reservation_specification (known after apply)

      + cpu_options (known after apply)

      + ebs_block_device (known after apply)

      + enclave_options (known after apply)

      + ephemeral_block_device (known after apply)

      + instance_market_options (known after apply)

      + maintenance_options (known after apply)

      + metadata_options {
          + http_endpoint               = "enabled"
          + http_protocol_ipv6          = "disabled"
          + http_put_response_hop_limit = (known after apply)
          + http_tokens                 = "required"
          + instance_metadata_tags      = (known after apply)
        }

      + network_interface (known after apply)

      + private_dns_name_options (known after apply)

      + root_block_device {
          + delete_on_termination = true
          + device_name           = (known after apply)
          + encrypted             = true
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + tags_all              = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = 8
          + volume_type           = "gp3"
        }
    }

  # aws_internet_gateway.igw will be created
  + resource "aws_internet_gateway" "igw" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name" = "yatri-dev-igw"
        }
      + tags_all = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-igw"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + vpc_id   = (known after apply)
    }

  # aws_route_table.public will be created
  + resource "aws_route_table" "public" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + cidr_block                 = "0.0.0.0/0"
              + gateway_id                 = (known after apply)
                # (11 unchanged attributes hidden)
            },
        ]
      + tags             = {
          + "Name" = "yatri-dev-public-rt"
        }
      + tags_all         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-public-rt"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + vpc_id           = (known after apply)
    }

  # aws_route_table_association.public will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # aws_s3_bucket.assets will be created
  + resource "aws_s3_bucket" "assets" {
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
      + tags                        = {
          + "Name" = "yatri-dev-assets"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-assets"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
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

  # aws_s3_bucket_public_access_block.assets will be created
  + resource "aws_s3_bucket_public_access_block" "assets" {
      + block_public_acls       = true
      + block_public_policy     = true
      + bucket                  = (known after apply)
      + id                      = (known after apply)
      + ignore_public_acls      = true
      + restrict_public_buckets = true
    }

  # aws_s3_bucket_server_side_encryption_configuration.assets will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + rule {
          + apply_server_side_encryption_by_default {
              + sse_algorithm     = "AES256"
                # (1 unchanged attribute hidden)
            }
        }
    }

  # aws_s3_bucket_versioning.assets will be created
  + resource "aws_s3_bucket_versioning" "assets" {
      + bucket = (known after apply)
      + id     = (known after apply)

      + versioning_configuration {
          + mfa_delete = (known after apply)
          + status     = "Enabled"
        }
    }

  # aws_s3_object.index will be created
  + resource "aws_s3_object" "index" {
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
      + content_type           = "text/html"
      + etag                   = (known after apply)
      + force_destroy          = false
      + id                     = (known after apply)
      + key                    = "site/index.html"
      + kms_key_id             = (known after apply)
      + server_side_encryption = (known after apply)
      + storage_class          = (known after apply)
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + version_id             = (known after apply)
    }

  # aws_security_group.web will be created
  + resource "aws_security_group" "web" {
      + arn                    = (known after apply)
      + description            = "HTTP in, everything out"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = "yatri-dev-web-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Name" = "yatri-dev-web-sg"
        }
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-web-sg"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + vpc_id                 = (known after apply)
    }

  # aws_subnet.public will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "ap-south-1a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.20.1.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = true
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + tags                                           = {
          + "Name" = "yatri-dev-public-a"
        }
      + tags_all                                       = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-public-a"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + vpc_id                                         = (known after apply)
    }

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.20.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + tags                                 = {
          + "Name" = "yatri-dev-vpc"
        }
      + tags_all                             = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "yatri-dev-vpc"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
    }

  # aws_vpc_security_group_egress_rule.all will be created
  + resource "aws_vpc_security_group_egress_rule" "all" {
      + arn                    = (known after apply)
      + cidr_ipv4              = "0.0.0.0/0"
      + description            = "All outbound"
      + id                     = (known after apply)
      + ip_protocol            = "-1"
      + security_group_id      = (known after apply)
      + security_group_rule_id = (known after apply)
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
    }

  # aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"] will be created
  + resource "aws_vpc_security_group_ingress_rule" "http" {
      + arn                    = (known after apply)
      + cidr_ipv4              = "0.0.0.0/0"
      + description            = "HTTP"
      + from_port              = 80
      + id                     = (known after apply)
      + ip_protocol            = "tcp"
      + security_group_id      = (known after apply)
      + security_group_rule_id = (known after apply)
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Project"     = "yatri"
          + "Session"     = "19-cloud-terraform-in-action"
        }
      + to_port                = 80
    }

  # random_id.bucket_suffix will be created
  + resource "random_id" "bucket_suffix" {
      + b64_std     = (known after apply)
      + b64_url     = (known after apply)
      + byte_length = 4
      + dec         = (known after apply)
      + hex         = (known after apply)
      + id          = (known after apply)
    }

Plan: 19 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + instance_id         = (known after apply)
  + instance_public_ip  = (known after apply)
  + s3_bucket           = (known after apply)
  + security_group_id   = (known after apply)
  + ssm_connect_command = (known after apply)
  + subnet_id           = (known after apply)
  + vpc_id              = (known after apply)
  + website_url         = (known after apply)

```

## terraform apply
```text
$ terraform apply -auto-approve infra.tfplan
random_id.bucket_suffix: Creating...
random_id.bucket_suffix: Creation complete after 0s [id=WJ4P4A]
aws_iam_role.web: Creating...
aws_vpc.main: Creating...
aws_s3_bucket.assets: Creating...
aws_iam_role.web: Creation complete after 0s [id=yatri-dev-web-role]
aws_iam_role_policy_attachment.ssm: Creating...
aws_iam_instance_profile.web: Creating...
aws_iam_role_policy_attachment.ssm: Creation complete after 0s [id=yatri-dev-web-role-20261007155753799500000001]
aws_s3_bucket.assets: Creation complete after 0s [id=yatri-dev-assets-589e0fe0]
data.aws_iam_policy_document.read_assets: Reading...
aws_s3_bucket_public_access_block.assets: Creating...
aws_s3_bucket_server_side_encryption_configuration.assets: Creating...
aws_s3_bucket_versioning.assets: Creating...
data.aws_iam_policy_document.read_assets: Read complete after 0s [id=2813782975]
aws_s3_object.index: Creating...
aws_iam_role_policy.read_assets: Creating...
aws_s3_object.index: Creation complete after 0s [id=site/index.html]
aws_s3_bucket_public_access_block.assets: Creation complete after 0s [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket_server_side_encryption_configuration.assets: Creation complete after 0s [id=yatri-dev-assets-589e0fe0]
aws_iam_role_policy.read_assets: Creation complete after 0s [id=yatri-dev-web-role:read-site-assets]
aws_s3_bucket_versioning.assets: Creation complete after 1s [id=yatri-dev-assets-589e0fe0]
aws_iam_instance_profile.web: Creation complete after 5s [id=yatri-dev-web-profile]
aws_vpc.main: Still creating... [00m10s elapsed]
aws_vpc.main: Creation complete after 10s [id=vpc-11b5df36]
aws_internet_gateway.igw: Creating...
aws_subnet.public: Creating...
aws_security_group.web: Creating...
aws_internet_gateway.igw: Creation complete after 0s [id=igw-cbfdbbfd]
aws_route_table.public: Creating...
aws_security_group.web: Creation complete after 1s [id=sg-34a1917233e6a7e04]
aws_vpc_security_group_egress_rule.all: Creating...
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Creating...
aws_vpc_security_group_egress_rule.all: Creation complete after 0s [id=sgr-c707c88323a5646b2]
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Creation complete after 0s [id=sgr-836c7ecd51177b5dc]
aws_route_table.public: Creation complete after 1s [id=rtb-2a90cf91]
aws_subnet.public: Still creating... [00m10s elapsed]
aws_subnet.public: Creation complete after 10s [id=subnet-fcadfbcc]
aws_route_table_association.public: Creating...
aws_route_table_association.public: Creation complete after 1s [id=rtbassoc-572a60fa]
aws_instance.web: Creating...
aws_instance.web: Still creating... [00m10s elapsed]
aws_instance.web: Creation complete after 11s [id=i-2baa79ed55b516629]

Apply complete! Resources: 19 added, 0 changed, 0 destroyed.

Outputs:

instance_id = "i-2baa79ed55b516629"
instance_public_ip = "54.214.75.242"
s3_bucket = "yatri-dev-assets-589e0fe0"
security_group_id = "sg-34a1917233e6a7e04"
ssm_connect_command = "aws ssm start-session --target i-2baa79ed55b516629 --region ap-south-1"
subnet_id = "subnet-fcadfbcc"
vpc_id = "vpc-11b5df36"
website_url = "http://ec2-54-214-75-242.ap-south-1.compute.amazonaws.com"

```

## Terraform state
```text
$ terraform state list
data.aws_ami.al2023
data.aws_availability_zones.available
data.aws_iam_policy_document.ec2_assume
data.aws_iam_policy_document.read_assets
aws_iam_instance_profile.web
aws_iam_role.web
aws_iam_role_policy.read_assets
aws_iam_role_policy_attachment.ssm
aws_instance.web
aws_internet_gateway.igw
aws_route_table.public
aws_route_table_association.public
aws_s3_bucket.assets
aws_s3_bucket_public_access_block.assets
aws_s3_bucket_server_side_encryption_configuration.assets
aws_s3_bucket_versioning.assets
aws_s3_object.index
aws_security_group.web
aws_subnet.public
aws_vpc.main
aws_vpc_security_group_egress_rule.all
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]
random_id.bucket_suffix

$ terraform state show aws_vpc.main
# aws_vpc.main:
resource "aws_vpc" "main" {
    arn                                  = "arn:aws:ec2:ap-south-1:000000000000:vpc/vpc-11b5df36"
    assign_generated_ipv6_cidr_block     = false
    cidr_block                           = "10.20.0.0/16"
    default_network_acl_id               = "acl-0de0ce3c"
    default_route_table_id               = "rtb-119051f0"
    default_security_group_id            = "sg-bfa0baf0e7c3f85d0"
    dhcp_options_id                      = "default"
    enable_dns_hostnames                 = true
    enable_dns_support                   = true
    enable_network_address_usage_metrics = false
    id                                   = "vpc-11b5df36"
    instance_tenancy                     = "default"
    ipv6_association_id                  = null
    ipv6_cidr_block                      = null
    ipv6_cidr_block_network_border_group = null
    ipv6_ipam_pool_id                    = null
    ipv6_netmask_length                  = 0
    main_route_table_id                  = "rtb-119051f0"
    owner_id                             = "000000000000"
    tags                                 = {
        "Name" = "yatri-dev-vpc"
    }
    tags_all                             = {
        "Environment" = "dev"
        "ManagedBy"   = "terraform"
        "Name"        = "yatri-dev-vpc"
        "Project"     = "yatri"
        "Session"     = "19-cloud-terraform-in-action"
    }
}

$ terraform state show aws_subnet.public
# aws_subnet.public:
resource "aws_subnet" "public" {
    arn                                            = "arn:aws:ec2:ap-south-1:000000000000:subnet/subnet-fcadfbcc"
    assign_ipv6_address_on_creation                = false
    availability_zone                              = "ap-south-1a"
    availability_zone_id                           = "aps1-az1"
    cidr_block                                     = "10.20.1.0/24"
    customer_owned_ipv4_pool                       = null
    enable_dns64                                   = false
    enable_lni_at_device_index                     = 0
    enable_resource_name_dns_a_record_on_launch    = false
    enable_resource_name_dns_aaaa_record_on_launch = false
    id                                             = "subnet-fcadfbcc"
    ipv6_cidr_block                                = null
    ipv6_cidr_block_association_id                 = null
    ipv6_native                                    = false
    map_customer_owned_ip_on_launch                = false
    map_public_ip_on_launch                        = true
    outpost_arn                                    = null
    owner_id                                       = "000000000000"
    private_dns_hostname_type_on_launch            = "ip-name"
    tags                                           = {
        "Name" = "yatri-dev-public-a"
    }
    tags_all                                       = {
        "Environment" = "dev"
        "ManagedBy"   = "terraform"
        "Name"        = "yatri-dev-public-a"
        "Project"     = "yatri"
        "Session"     = "19-cloud-terraform-in-action"
    }
    vpc_id                                         = "vpc-11b5df36"
}

$ terraform state show aws_instance.web | grep -E '^ +(ami|id|instance_type|subnet_id|private_ip|public_ip|vpc_security_group_ids|iam_instance_profile|instance_state) '
    ami                                  = "ami-089d868c1c73e3728"
    iam_instance_profile                 = "yatri-dev-web-profile"
    id                                   = "i-2baa79ed55b516629"
    instance_state                       = "running"
    instance_type                        = "t3.micro"
    private_ip                           = "10.20.1.4"
    public_ip                            = "54.214.75.242"
    subnet_id                            = "subnet-fcadfbcc"
    vpc_security_group_ids               = [

```

## terraform output
```text
$ terraform output
instance_id = "i-2baa79ed55b516629"
instance_public_ip = "54.214.75.242"
s3_bucket = "yatri-dev-assets-589e0fe0"
security_group_id = "sg-34a1917233e6a7e04"
ssm_connect_command = "aws ssm start-session --target i-2baa79ed55b516629 --region ap-south-1"
subnet_id = "subnet-fcadfbcc"
vpc_id = "vpc-11b5df36"
website_url = "http://ec2-54-214-75-242.ap-south-1.compute.amazonaws.com"

```

## Verify the resources through the AWS API (inside LocalStack)
```text
$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-vpcs --vpc-ids vpc-11b5df36 --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}' --output table
---------------------------------------------------
|                  DescribeVpcs                   |
+--------------+----------------+-----------------+
|     Cidr     |      Id        |      Name       |
+--------------+----------------+-----------------+
|  10.20.0.0/16|  vpc-11b5df36  |  yatri-dev-vpc  |
+--------------+----------------+-----------------+

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-subnets --filters Name=vpc-id,Values=vpc-11b5df36 --query 'Subnets[].{Id:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,PublicIp:MapPublicIpOnLaunch}' --output table
----------------------------------------------------------------
|                        DescribeSubnets                       |
+-------------+----------------+-------------------+-----------+
|     AZ      |     Cidr       |        Id         | PublicIp  |
+-------------+----------------+-------------------+-----------+
|  ap-south-1a|  10.20.1.0/24  |  subnet-fcadfbcc  |  True     |
+-------------+----------------+-------------------+-----------+

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-11b5df36 --query 'RouteTables[].Routes[]' --output table
------------------------------------------------------------------------
|                          DescribeRouteTables                         |
+-----------------------+---------------+--------------------+---------+
| DestinationCidrBlock  |   GatewayId   |      Origin        |  State  |
+-----------------------+---------------+--------------------+---------+
|  10.20.0.0/16         |  local        |  CreateRouteTable  |  active |
|  10.20.0.0/16         |  local        |  CreateRouteTable  |  active |
|  0.0.0.0/0            |  igw-cbfdbbfd |  CreateRoute       |  active |
+-----------------------+---------------+--------------------+---------+

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-security-groups --group-ids sg-34a1917233e6a7e04 --query 'SecurityGroups[].IpPermissions[]' --output table
--------------------------------------
|       DescribeSecurityGroups       |
+----------+--------------+----------+
| FromPort | IpProtocol   | ToPort   |
+----------+--------------+----------+
|  80      |  tcp         |  80      |
+----------+--------------+----------+
||             IpRanges             ||
|+---------------+------------------+|
||    CidrIp     |   Description    ||
|+---------------+------------------+|
||  0.0.0.0/0    |  HTTP            ||
|+---------------+------------------+|

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-instances --instance-ids i-2baa79ed55b516629 --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,State:State.Name,Subnet:SubnetId,PrivateIp:PrivateIpAddress}' --output table
--------------------------------------------------------------------------------
|                               DescribeInstances                              |
+----------------------+------------+----------+------------------+------------+
|          Id          | PrivateIp  |  State   |     Subnet       |   Type     |
+----------------------+------------+----------+------------------+------------+
|  i-2baa79ed55b516629 |  10.20.1.4 |  running |  subnet-fcadfbcc |  t3.micro  |
+----------------------+------------+----------+------------------+------------+

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal s3 ls s3://yatri-dev-assets-589e0fe0 --recursive
2026-10-07 15:57:54        181 site/index.html

```

## Drift: change the state outside Terraform, plan detects it
```text
$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 create-tags --resources vpc-11b5df36 --tags Key=Name,Value=renamed-by-hand

$ terraform plan | grep -E '~|Name|Plan:'
  ~ update in-place
  ~ resource "aws_vpc" "main" {
      ~ tags                                 = {
          ~ "Name" = "renamed-by-hand" -> "yatri-dev-vpc"
      ~ tags_all                             = {
          ~ "Name"        = "renamed-by-hand" -> "yatri-dev-vpc"
Plan: 0 to add, 1 to change, 0 to destroy.

$ terraform apply -auto-approve
random_id.bucket_suffix: Refreshing state... [id=WJ4P4A]
data.aws_availability_zones.available: Reading...
data.aws_ami.al2023: Reading...
data.aws_iam_policy_document.ec2_assume: Reading...
aws_vpc.main: Refreshing state... [id=vpc-11b5df36]
data.aws_iam_policy_document.ec2_assume: Read complete after 0s [id=2851119427]
aws_s3_bucket.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_iam_role.web: Refreshing state... [id=yatri-dev-web-role]
data.aws_availability_zones.available: Read complete after 0s [id=ap-south-1]
data.aws_ami.al2023: Read complete after 1s [id=ami-089d868c1c73e3728]
aws_s3_bucket_public_access_block.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket_versioning.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket_server_side_encryption_configuration.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_s3_object.index: Refreshing state... [id=site/index.html]
data.aws_iam_policy_document.read_assets: Reading...
data.aws_iam_policy_document.read_assets: Read complete after 0s [id=2813782975]
aws_iam_role_policy_attachment.ssm: Refreshing state... [id=yatri-dev-web-role-20261007155753799500000001]
aws_iam_role_policy.read_assets: Refreshing state... [id=yatri-dev-web-role:read-site-assets]
aws_iam_instance_profile.web: Refreshing state... [id=yatri-dev-web-profile]
aws_internet_gateway.igw: Refreshing state... [id=igw-cbfdbbfd]
aws_security_group.web: Refreshing state... [id=sg-34a1917233e6a7e04]
aws_subnet.public: Refreshing state... [id=subnet-fcadfbcc]
aws_route_table.public: Refreshing state... [id=rtb-2a90cf91]
aws_vpc_security_group_egress_rule.all: Refreshing state... [id=sgr-c707c88323a5646b2]
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Refreshing state... [id=sgr-836c7ecd51177b5dc]
aws_route_table_association.public: Refreshing state... [id=rtbassoc-572a60fa]
aws_instance.web: Refreshing state... [id=i-2baa79ed55b516629]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_vpc.main will be updated in-place
  ~ resource "aws_vpc" "main" {
        id                                   = "vpc-11b5df36"
      ~ tags                                 = {
          ~ "Name" = "renamed-by-hand" -> "yatri-dev-vpc"
        }
      ~ tags_all                             = {
          ~ "Name"        = "renamed-by-hand" -> "yatri-dev-vpc"
            # (4 unchanged elements hidden)
        }
        # (18 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
aws_vpc.main: Modifying... [id=vpc-11b5df36]
aws_vpc.main: Modifications complete after 0s [id=vpc-11b5df36]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

Outputs:

instance_id = "i-2baa79ed55b516629"
instance_public_ip = "54.214.75.242"
s3_bucket = "yatri-dev-assets-589e0fe0"
security_group_id = "sg-34a1917233e6a7e04"
ssm_connect_command = "aws ssm start-session --target i-2baa79ed55b516629 --region ap-south-1"
subnet_id = "subnet-fcadfbcc"
vpc_id = "vpc-11b5df36"
website_url = "http://ec2-54-214-75-242.ap-south-1.compute.amazonaws.com"

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-vpcs --vpc-ids vpc-11b5df36 --query 'Vpcs[].Tags[?Key==`Name`].Value' --output text
yatri-dev-vpc

```

## terraform destroy
```text
$ terraform destroy -auto-approve
random_id.bucket_suffix: Refreshing state... [id=WJ4P4A]
data.aws_iam_policy_document.ec2_assume: Reading...
data.aws_availability_zones.available: Reading...
data.aws_ami.al2023: Reading...
aws_vpc.main: Refreshing state... [id=vpc-11b5df36]
data.aws_iam_policy_document.ec2_assume: Read complete after 0s [id=2851119427]
aws_s3_bucket.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_iam_role.web: Refreshing state... [id=yatri-dev-web-role]
data.aws_availability_zones.available: Read complete after 0s [id=ap-south-1]
data.aws_ami.al2023: Read complete after 0s [id=ami-089d868c1c73e3728]
aws_s3_bucket_versioning.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket_public_access_block.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket_server_side_encryption_configuration.assets: Refreshing state... [id=yatri-dev-assets-589e0fe0]
aws_s3_object.index: Refreshing state... [id=site/index.html]
data.aws_iam_policy_document.read_assets: Reading...
data.aws_iam_policy_document.read_assets: Read complete after 0s [id=2813782975]
aws_iam_role_policy_attachment.ssm: Refreshing state... [id=yatri-dev-web-role-20261007155753799500000001]
aws_iam_role_policy.read_assets: Refreshing state... [id=yatri-dev-web-role:read-site-assets]
aws_iam_instance_profile.web: Refreshing state... [id=yatri-dev-web-profile]
aws_internet_gateway.igw: Refreshing state... [id=igw-cbfdbbfd]
aws_subnet.public: Refreshing state... [id=subnet-fcadfbcc]
aws_security_group.web: Refreshing state... [id=sg-34a1917233e6a7e04]
aws_route_table.public: Refreshing state... [id=rtb-2a90cf91]
aws_vpc_security_group_egress_rule.all: Refreshing state... [id=sgr-c707c88323a5646b2]
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Refreshing state... [id=sgr-836c7ecd51177b5dc]
aws_route_table_association.public: Refreshing state... [id=rtbassoc-572a60fa]
aws_instance.web: Refreshing state... [id=i-2baa79ed55b516629]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # aws_iam_instance_profile.web will be destroyed
  - resource "aws_iam_instance_profile" "web" {
      - arn         = "arn:aws:iam::000000000000:instance-profile/yatri-dev-web-profile" -> null
      - create_date = "2026-10-07T15:57:53Z" -> null
      - id          = "yatri-dev-web-profile" -> null
      - name        = "yatri-dev-web-profile" -> null
      - path        = "/" -> null
      - role        = "yatri-dev-web-role" -> null
      - tags        = {} -> null
      - tags_all    = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - unique_id   = "kq5ulx27ccqffzggdva5" -> null
        # (1 unchanged attribute hidden)
    }

  # aws_iam_role.web will be destroyed
  - resource "aws_iam_role" "web" {
      - arn                   = "arn:aws:iam::000000000000:role/yatri-dev-web-role" -> null
      - assume_role_policy    = jsonencode(
            {
              - Statement = [
                  - {
                      - Action    = "sts:AssumeRole"
                      - Effect    = "Allow"
                      - Principal = {
                          - Service = "ec2.amazonaws.com"
                        }
                    },
                ]
              - Version   = "2012-10-17"
            }
        ) -> null
      - create_date           = "2026-10-07T15:57:53Z" -> null
      - force_detach_policies = false -> null
      - id                    = "yatri-dev-web-role" -> null
      - managed_policy_arns   = [
          - "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        ] -> null
      - max_session_duration  = 3600 -> null
      - name                  = "yatri-dev-web-role" -> null
      - path                  = "/" -> null
      - tags                  = {} -> null
      - tags_all              = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - unique_id             = "AROAQAAAAAAAIPKN6GD3S" -> null
        # (3 unchanged attributes hidden)

      - inline_policy {
          - name   = "read-site-assets" -> null
          - policy = jsonencode(
                {
                  - Statement = [
                      - {
                          - Action   = "s3:GetObject"
                          - Effect   = "Allow"
                          - Resource = "arn:aws:s3:::yatri-dev-assets-589e0fe0/site/*"
                          - Sid      = "ReadSiteContent"
                        },
                      - {
                          - Action   = "s3:ListBucket"
                          - Effect   = "Allow"
                          - Resource = "arn:aws:s3:::yatri-dev-assets-589e0fe0"
                          - Sid      = "ListBucket"
                        },
                    ]
                  - Version   = "2012-10-17"
                }
            ) -> null
        }
    }

  # aws_iam_role_policy.read_assets will be destroyed
  - resource "aws_iam_role_policy" "read_assets" {
      - id          = "yatri-dev-web-role:read-site-assets" -> null
      - name        = "read-site-assets" -> null
      - policy      = jsonencode(
            {
              - Statement = [
                  - {
                      - Action   = "s3:GetObject"
                      - Effect   = "Allow"
                      - Resource = "arn:aws:s3:::yatri-dev-assets-589e0fe0/site/*"
                      - Sid      = "ReadSiteContent"
                    },
                  - {
                      - Action   = "s3:ListBucket"
                      - Effect   = "Allow"
                      - Resource = "arn:aws:s3:::yatri-dev-assets-589e0fe0"
                      - Sid      = "ListBucket"
                    },
                ]
              - Version   = "2012-10-17"
            }
        ) -> null
      - role        = "yatri-dev-web-role" -> null
        # (1 unchanged attribute hidden)
    }

  # aws_iam_role_policy_attachment.ssm will be destroyed
  - resource "aws_iam_role_policy_attachment" "ssm" {
      - id         = "yatri-dev-web-role-20261007155753799500000001" -> null
      - policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" -> null
      - role       = "yatri-dev-web-role" -> null
    }

  # aws_instance.web will be destroyed
  - resource "aws_instance" "web" {
      - ami                                  = "ami-089d868c1c73e3728" -> null
      - arn                                  = "arn:aws:ec2:ap-south-1::instance/i-2baa79ed55b516629" -> null
      - associate_public_ip_address          = true -> null
      - availability_zone                    = "ap-south-1a" -> null
      - disable_api_stop                     = false -> null
      - disable_api_termination              = false -> null
      - ebs_optimized                        = false -> null
      - get_password_data                    = false -> null
      - hibernation                          = false -> null
      - iam_instance_profile                 = "yatri-dev-web-profile" -> null
      - id                                   = "i-2baa79ed55b516629" -> null
      - instance_initiated_shutdown_behavior = "stop" -> null
      - instance_state                       = "running" -> null
      - instance_type                        = "t3.micro" -> null
      - ipv6_address_count                   = 0 -> null
      - ipv6_addresses                       = [] -> null
      - monitoring                           = false -> null
      - placement_partition_number           = 0 -> null
      - primary_network_interface_id         = "eni-f79e48b5" -> null
      - private_dns                          = "ip-10-20-1-4.ap-south-1.compute.internal" -> null
      - private_ip                           = "10.20.1.4" -> null
      - public_dns                           = "ec2-54-214-75-242.ap-south-1.compute.amazonaws.com" -> null
      - public_ip                            = "54.214.75.242" -> null
      - secondary_private_ips                = [] -> null
      - security_groups                      = [] -> null
      - source_dest_check                    = true -> null
      - subnet_id                            = "subnet-fcadfbcc" -> null
      - tags                                 = {
          - "Name" = "yatri-dev-web"
        } -> null
      - tags_all                             = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-web"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - tenancy                              = "default" -> null
      - user_data                            = "5b2e56dc8902a765fbe93d4b73a69115f1be887a" -> null
      - user_data_replace_on_change          = true -> null
      - vpc_security_group_ids               = [
          - "sg-34a1917233e6a7e04",
        ] -> null
        # (7 unchanged attributes hidden)

      - ebs_block_device {
          - delete_on_termination = true -> null
          - device_name           = "/dev/xvda" -> null
          - encrypted             = true -> null
          - iops                  = 3000 -> null
          - kms_key_id            = "arn:aws:kms:ap-south-1:000000000000:key/56bc5a46-d940-467e-96fa-ba410a1e5062" -> null
          - tags                  = {
              - "Environment" = "dev"
              - "ManagedBy"   = "terraform"
              - "Project"     = "yatri"
              - "Session"     = "19-cloud-terraform-in-action"
            } -> null
          - tags_all              = {
              - "Environment" = "dev"
              - "ManagedBy"   = "terraform"
              - "Project"     = "yatri"
              - "Session"     = "19-cloud-terraform-in-action"
            } -> null
          - throughput            = 0 -> null
          - volume_id             = "vol-564f5274" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp3" -> null
            # (1 unchanged attribute hidden)
        }

      - root_block_device {
          - delete_on_termination = true -> null
          - encrypted             = true -> null
          - iops                  = 0 -> null
          - tags                  = {} -> null
          - tags_all              = {} -> null
          - throughput            = 0 -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp3" -> null
            # (3 unchanged attributes hidden)
        }
    }

  # aws_internet_gateway.igw will be destroyed
  - resource "aws_internet_gateway" "igw" {
      - arn      = "arn:aws:ec2:ap-south-1:000000000000:internet-gateway/igw-cbfdbbfd" -> null
      - id       = "igw-cbfdbbfd" -> null
      - owner_id = "000000000000" -> null
      - tags     = {
          - "Name" = "yatri-dev-igw"
        } -> null
      - tags_all = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-igw"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - vpc_id   = "vpc-11b5df36" -> null
    }

  # aws_route_table.public will be destroyed
  - resource "aws_route_table" "public" {
      - arn              = "arn:aws:ec2:ap-south-1:000000000000:route-table/rtb-2a90cf91" -> null
      - id               = "rtb-2a90cf91" -> null
      - owner_id         = "000000000000" -> null
      - propagating_vgws = [] -> null
      - route            = [
          - {
              - cidr_block                 = "0.0.0.0/0"
              - gateway_id                 = "igw-cbfdbbfd"
                # (11 unchanged attributes hidden)
            },
        ] -> null
      - tags             = {
          - "Name" = "yatri-dev-public-rt"
        } -> null
      - tags_all         = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-public-rt"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - vpc_id           = "vpc-11b5df36" -> null
    }

  # aws_route_table_association.public will be destroyed
  - resource "aws_route_table_association" "public" {
      - id             = "rtbassoc-572a60fa" -> null
      - route_table_id = "rtb-2a90cf91" -> null
      - subnet_id      = "subnet-fcadfbcc" -> null
        # (1 unchanged attribute hidden)
    }

  # aws_s3_bucket.assets will be destroyed
  - resource "aws_s3_bucket" "assets" {
      - arn                         = "arn:aws:s3:::yatri-dev-assets-589e0fe0" -> null
      - bucket                      = "yatri-dev-assets-589e0fe0" -> null
      - bucket_domain_name          = "yatri-dev-assets-589e0fe0.s3.amazonaws.com" -> null
      - bucket_regional_domain_name = "yatri-dev-assets-589e0fe0.s3.ap-south-1.amazonaws.com" -> null
      - force_destroy               = true -> null
      - hosted_zone_id              = "Z11RGJOFQNVJUP" -> null
      - id                          = "yatri-dev-assets-589e0fe0" -> null
      - object_lock_enabled         = false -> null
      - region                      = "ap-south-1" -> null
      - request_payer               = "BucketOwner" -> null
      - tags                        = {
          - "Name" = "yatri-dev-assets"
        } -> null
      - tags_all                    = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-assets"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
        # (3 unchanged attributes hidden)

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
              - bucket_key_enabled = false -> null

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

  # aws_s3_bucket_public_access_block.assets will be destroyed
  - resource "aws_s3_bucket_public_access_block" "assets" {
      - block_public_acls       = true -> null
      - block_public_policy     = true -> null
      - bucket                  = "yatri-dev-assets-589e0fe0" -> null
      - id                      = "yatri-dev-assets-589e0fe0" -> null
      - ignore_public_acls      = true -> null
      - restrict_public_buckets = true -> null
    }

  # aws_s3_bucket_server_side_encryption_configuration.assets will be destroyed
  - resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
      - bucket                = "yatri-dev-assets-589e0fe0" -> null
      - id                    = "yatri-dev-assets-589e0fe0" -> null
        # (1 unchanged attribute hidden)

      - rule {
          - bucket_key_enabled = false -> null

          - apply_server_side_encryption_by_default {
              - sse_algorithm     = "AES256" -> null
                # (1 unchanged attribute hidden)
            }
        }
    }

  # aws_s3_bucket_versioning.assets will be destroyed
  - resource "aws_s3_bucket_versioning" "assets" {
      - bucket                = "yatri-dev-assets-589e0fe0" -> null
      - id                    = "yatri-dev-assets-589e0fe0" -> null
        # (1 unchanged attribute hidden)

      - versioning_configuration {
          - status     = "Enabled" -> null
            # (1 unchanged attribute hidden)
        }
    }

  # aws_s3_object.index will be destroyed
  - resource "aws_s3_object" "index" {
      - arn                           = "arn:aws:s3:::yatri-dev-assets-589e0fe0/site/index.html" -> null
      - bucket                        = "yatri-dev-assets-589e0fe0" -> null
      - bucket_key_enabled            = false -> null
      - content                       = <<-EOT
            <html>
              <body>
                <h1>Hello from Terraform</h1>
                <p>Project: yatri-dev</p>
                <p>Served by EC2, content fetched from S3 bucket yatri-dev-assets-589e0fe0</p>
              </body>
            </html>
        EOT -> null
      - content_type                  = "text/html" -> null
      - etag                          = "f8baae4694dc63274e7884179afb088a" -> null
      - force_destroy                 = false -> null
      - id                            = "site/index.html" -> null
      - key                           = "site/index.html" -> null
      - metadata                      = {} -> null
      - server_side_encryption        = "AES256" -> null
      - storage_class                 = "STANDARD" -> null
      - tags                          = {} -> null
      - tags_all                      = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - version_id                    = "null" -> null
        # (13 unchanged attributes hidden)
    }

  # aws_security_group.web will be destroyed
  - resource "aws_security_group" "web" {
      - arn                    = "arn:aws:ec2:ap-south-1:000000000000:security-group/sg-34a1917233e6a7e04" -> null
      - description            = "HTTP in, everything out" -> null
      - egress                 = [
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "All outbound"
              - from_port        = 0
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "-1"
              - security_groups  = []
              - self             = false
              - to_port          = 0
            },
        ] -> null
      - id                     = "sg-34a1917233e6a7e04" -> null
      - ingress                = [
          - {
              - cidr_blocks      = [
                  - "0.0.0.0/0",
                ]
              - description      = "HTTP"
              - from_port        = 80
              - ipv6_cidr_blocks = []
              - prefix_list_ids  = []
              - protocol         = "tcp"
              - security_groups  = []
              - self             = false
              - to_port          = 80
            },
        ] -> null
      - name                   = "yatri-dev-web-sg" -> null
      - owner_id               = "000000000000" -> null
      - revoke_rules_on_delete = false -> null
      - tags                   = {
          - "Name" = "yatri-dev-web-sg"
        } -> null
      - tags_all               = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-web-sg"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - vpc_id                 = "vpc-11b5df36" -> null
        # (1 unchanged attribute hidden)
    }

  # aws_subnet.public will be destroyed
  - resource "aws_subnet" "public" {
      - arn                                            = "arn:aws:ec2:ap-south-1:000000000000:subnet/subnet-fcadfbcc" -> null
      - assign_ipv6_address_on_creation                = false -> null
      - availability_zone                              = "ap-south-1a" -> null
      - availability_zone_id                           = "aps1-az1" -> null
      - cidr_block                                     = "10.20.1.0/24" -> null
      - enable_dns64                                   = false -> null
      - enable_lni_at_device_index                     = 0 -> null
      - enable_resource_name_dns_a_record_on_launch    = false -> null
      - enable_resource_name_dns_aaaa_record_on_launch = false -> null
      - id                                             = "subnet-fcadfbcc" -> null
      - ipv6_native                                    = false -> null
      - map_customer_owned_ip_on_launch                = false -> null
      - map_public_ip_on_launch                        = true -> null
      - owner_id                                       = "000000000000" -> null
      - private_dns_hostname_type_on_launch            = "ip-name" -> null
      - tags                                           = {
          - "Name" = "yatri-dev-public-a"
        } -> null
      - tags_all                                       = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-public-a"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - vpc_id                                         = "vpc-11b5df36" -> null
        # (4 unchanged attributes hidden)
    }

  # aws_vpc.main will be destroyed
  - resource "aws_vpc" "main" {
      - arn                                  = "arn:aws:ec2:ap-south-1:000000000000:vpc/vpc-11b5df36" -> null
      - assign_generated_ipv6_cidr_block     = false -> null
      - cidr_block                           = "10.20.0.0/16" -> null
      - default_network_acl_id               = "acl-0de0ce3c" -> null
      - default_route_table_id               = "rtb-119051f0" -> null
      - default_security_group_id            = "sg-bfa0baf0e7c3f85d0" -> null
      - dhcp_options_id                      = "default" -> null
      - enable_dns_hostnames                 = true -> null
      - enable_dns_support                   = true -> null
      - enable_network_address_usage_metrics = false -> null
      - id                                   = "vpc-11b5df36" -> null
      - instance_tenancy                     = "default" -> null
      - ipv6_netmask_length                  = 0 -> null
      - main_route_table_id                  = "rtb-119051f0" -> null
      - owner_id                             = "000000000000" -> null
      - tags                                 = {
          - "Name" = "yatri-dev-vpc"
        } -> null
      - tags_all                             = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Name"        = "yatri-dev-vpc"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
        # (4 unchanged attributes hidden)
    }

  # aws_vpc_security_group_egress_rule.all will be destroyed
  - resource "aws_vpc_security_group_egress_rule" "all" {
      - arn                    = "arn:aws:ec2:ap-south-1::security-group-rule/sgr-c707c88323a5646b2" -> null
      - cidr_ipv4              = "0.0.0.0/0" -> null
      - description            = "All outbound" -> null
      - id                     = "sgr-c707c88323a5646b2" -> null
      - ip_protocol            = "-1" -> null
      - security_group_id      = "sg-34a1917233e6a7e04" -> null
      - security_group_rule_id = "sgr-c707c88323a5646b2" -> null
      - tags_all               = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
    }

  # aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"] will be destroyed
  - resource "aws_vpc_security_group_ingress_rule" "http" {
      - arn                    = "arn:aws:ec2:ap-south-1::security-group-rule/sgr-836c7ecd51177b5dc" -> null
      - cidr_ipv4              = "0.0.0.0/0" -> null
      - description            = "HTTP" -> null
      - from_port              = 80 -> null
      - id                     = "sgr-836c7ecd51177b5dc" -> null
      - ip_protocol            = "tcp" -> null
      - security_group_id      = "sg-34a1917233e6a7e04" -> null
      - security_group_rule_id = "sgr-836c7ecd51177b5dc" -> null
      - tags_all               = {
          - "Environment" = "dev"
          - "ManagedBy"   = "terraform"
          - "Project"     = "yatri"
          - "Session"     = "19-cloud-terraform-in-action"
        } -> null
      - to_port                = 80 -> null
    }

  # random_id.bucket_suffix will be destroyed
  - resource "random_id" "bucket_suffix" {
      - b64_std     = "WJ4P4A==" -> null
      - b64_url     = "WJ4P4A" -> null
      - byte_length = 4 -> null
      - dec         = "1486753760" -> null
      - hex         = "589e0fe0" -> null
      - id          = "WJ4P4A" -> null
    }

Plan: 0 to add, 0 to change, 19 to destroy.

Changes to Outputs:
  - instance_id         = "i-2baa79ed55b516629" -> null
  - instance_public_ip  = "54.214.75.242" -> null
  - s3_bucket           = "yatri-dev-assets-589e0fe0" -> null
  - security_group_id   = "sg-34a1917233e6a7e04" -> null
  - ssm_connect_command = "aws ssm start-session --target i-2baa79ed55b516629 --region ap-south-1" -> null
  - subnet_id           = "subnet-fcadfbcc" -> null
  - vpc_id              = "vpc-11b5df36" -> null
  - website_url         = "http://ec2-54-214-75-242.ap-south-1.compute.amazonaws.com" -> null
aws_s3_bucket_public_access_block.assets: Destroying... [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket_versioning.assets: Destroying... [id=yatri-dev-assets-589e0fe0]
aws_iam_role_policy_attachment.ssm: Destroying... [id=yatri-dev-web-role-20261007155753799500000001]
aws_s3_bucket_server_side_encryption_configuration.assets: Destroying... [id=yatri-dev-assets-589e0fe0]
aws_vpc_security_group_egress_rule.all: Destroying... [id=sgr-c707c88323a5646b2]
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Destroying... [id=sgr-836c7ecd51177b5dc]
aws_instance.web: Destroying... [id=i-2baa79ed55b516629]
aws_s3_bucket_versioning.assets: Destruction complete after 0s
aws_iam_role_policy_attachment.ssm: Destruction complete after 0s
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Destruction complete after 0s
aws_s3_bucket_server_side_encryption_configuration.assets: Destruction complete after 0s
aws_vpc_security_group_egress_rule.all: Destruction complete after 0s
aws_s3_bucket_public_access_block.assets: Destruction complete after 1s
aws_instance.web: Still destroying... [id=i-2baa79ed55b516629, 00m10s elapsed]
aws_instance.web: Destruction complete after 11s
aws_route_table_association.public: Destroying... [id=rtbassoc-572a60fa]
aws_iam_role_policy.read_assets: Destroying... [id=yatri-dev-web-role:read-site-assets]
aws_iam_instance_profile.web: Destroying... [id=yatri-dev-web-profile]
aws_security_group.web: Destroying... [id=sg-34a1917233e6a7e04]
aws_s3_object.index: Destroying... [id=site/index.html]
aws_s3_object.index: Destruction complete after 0s
aws_iam_role_policy.read_assets: Destruction complete after 0s
aws_s3_bucket.assets: Destroying... [id=yatri-dev-assets-589e0fe0]
aws_s3_bucket.assets: Destruction complete after 0s
random_id.bucket_suffix: Destroying... [id=WJ4P4A]
random_id.bucket_suffix: Destruction complete after 0s
aws_route_table_association.public: Destruction complete after 0s
aws_route_table.public: Destroying... [id=rtb-2a90cf91]
aws_subnet.public: Destroying... [id=subnet-fcadfbcc]
aws_iam_instance_profile.web: Destruction complete after 0s
aws_iam_role.web: Destroying... [id=yatri-dev-web-role]
aws_security_group.web: Destruction complete after 0s
aws_subnet.public: Destruction complete after 0s
aws_iam_role.web: Destruction complete after 0s
aws_route_table.public: Destruction complete after 0s
aws_internet_gateway.igw: Destroying... [id=igw-cbfdbbfd]
aws_internet_gateway.igw: Destruction complete after 0s
aws_vpc.main: Destroying... [id=vpc-11b5df36]
aws_vpc.main: Destruction complete after 0s

Destroy complete! Resources: 19 destroyed.

$ terraform state list

$ docker exec -e AWS_DEFAULT_REGION=ap-south-1 localstack awslocal ec2 describe-vpcs --filters Name=tag:ManagedBy,Values=terraform --query 'Vpcs[].VpcId'
[]

```
