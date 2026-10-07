# Cloud infrastructure for the Yatri platform on AWS:
#
#   VPC (2 AZs)
#    ├── public subnets  x2  -> Internet Gateway, NAT Gateway, load balancers
#    └── private subnets x2  -> EKS worker nodes (no public IPs)
#   EKS control plane + managed node group
#   ECR repository           -> CI pushes images here (scan on push)
#   S3 bucket                -> backups of the trips data
#
# Plain aws_* resources (no community modules) so every piece is visible.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
  # 10.30.0.0/16 -> public 10.30.0.0/20, 10.30.16.0/20; private 10.30.128.0/20, 10.30.144.0/20
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

# ===================================================================== VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # nothing here needs one: NAT uses an EIP, LBs get their own
  tags = {
    Name                                  = "${local.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb"              = "1" # public load balancers go here
    "kubernetes.io/cluster/${local.name}" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name                                  = "${local.name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb"     = "1"
    "kubernetes.io/cluster/${local.name}" = "shared"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip" }
}

# One NAT Gateway keeps the lab cheap; production would use one per AZ.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${local.name}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${local.name}-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ===================================================================== EKS
data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.name}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = local.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = true
    # Private by default. The public endpoint is only enabled when specific
    # CIDRs (an office or VPN range) are listed - never 0.0.0.0/0.
    endpoint_public_access = length(var.api_allowed_cidrs) > 0
    public_access_cidrs    = length(var.api_allowed_cidrs) > 0 ? var.api_allowed_cidrs : null
  }

  access_config {
    authentication_mode = "API"
  }

  # Encrypt Kubernetes Secrets in etcd with a customer-managed KMS key.
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_kms_key" "eks" {
  description             = "${local.name} EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.name}-eks-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id # nodes never get public IPs
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    max_size     = var.node_max
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ===================================================================== ECR
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}/yatri-trips"
  image_tag_mutability = "IMMUTABLE" # a tag always means the same image

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 30 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}

# ============================================================ S3 BACKUPS
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "backups" {
  bucket = "${local.name}-backups-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "backups" {
  description             = "${local.name} backup bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.backups.arn # customer-managed, rotated yearly
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================== GitHub Actions -> AWS (OIDC)
# CI authenticates with short-lived tokens; no AWS keys are stored in GitHub.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name               = "${local.name}-github-ci"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

data "aws_iam_policy_document" "ci_push" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "ci_push" {
  name   = "push-yatri-image"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.ci_push.json
}
