# RESOURCES: the infrastructure itself.
#
#   Terraform
#     ├── VPC
#     ├── Subnet  (+ Internet Gateway + Route Table)
#     ├── Security Group
#     ├── EC2     (nginx via user_data, IAM role for S3 + SSM)
#     └── S3
#
# Terraform builds a dependency graph from the references between resources
# (implicit dependencies) plus any explicit depends_on, and creates resources
# in that order - in parallel wherever the graph allows.

locals {
  name = "${var.project_name}-${var.environment}"
}

# ----------------------------------------------------------- DATA SOURCES
# Read-only lookups: nothing is created.

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ===================================================================== VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

# ================================================================== SUBNET
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id # implicit dependency on the VPC
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-public-a" }
}

# The subnet is only "public" because of the route below.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ========================================================== SECURITY GROUP
resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "HTTP in, everything out"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-web-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

# SSH is only opened if CIDRs are explicitly given; the default is none.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "SSH"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ====================================================================== S3
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "assets" {
  bucket        = "${local.name}-assets-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = { Name = "${local.name}-assets" }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# The page the EC2 instance will serve, stored in S3.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.assets.id
  key          = "site/index.html"
  content_type = "text/html"
  content      = <<-HTML
    <html>
      <body>
        <h1>Hello from Terraform</h1>
        <p>Project: ${local.name}</p>
        <p>Served by EC2, content fetched from S3 bucket ${aws_s3_bucket.assets.id}</p>
      </body>
    </html>
  HTML
}

# ============================================================ IAM FOR EC2
# The instance reads its content from S3 through a role - no access keys
# anywhere - and can be reached through SSM Session Manager without SSH.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${local.name}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "read_assets" {
  statement {
    sid       = "ReadSiteContent"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.assets.arn}/site/*"]
  }

  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.assets.arn]
  }
}

resource "aws_iam_role_policy" "read_assets" {
  name   = "read-site-assets"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.read_assets.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${local.name}-web-profile"
  role = aws_iam_role.web.name
}

# ===================================================================== EC2
resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name
  key_name               = var.key_name

  # Require IMDSv2 - blocks the SSRF-to-credentials attack path.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  # Bootstraps nginx and pulls the page from S3 using the instance role.
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y nginx
    aws s3 cp s3://${aws_s3_bucket.assets.id}/site/index.html /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF

  user_data_replace_on_change = true

  # EXPLICIT dependency: the page must exist in S3 before the instance boots
  # and tries to download it. Nothing in the arguments above references the
  # object, so Terraform cannot infer this ordering on its own.
  depends_on = [
    aws_s3_object.index,
    aws_iam_role_policy.read_assets,
    aws_route_table_association.public,
  ]

  tags = { Name = "${local.name}-web" }
}
