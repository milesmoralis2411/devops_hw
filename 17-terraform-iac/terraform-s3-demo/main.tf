# S3 bucket names are globally unique across ALL AWS accounts, so a random
# suffix avoids collisions with anyone else running the same demo.
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project_name}-${var.environment}-${random_id.suffix.hex}"
}

# ---------------------------------------------------------------- the bucket
resource "aws_s3_bucket" "demo" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = local.bucket_name
  }
}

# ------------------------------------------------------------- versioning
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ------------------------------------------------- encryption at rest (SSE)
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# --------------------------------------------- block ALL public access
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------- ownership: disable ACLs
resource "aws_s3_bucket_ownership_controls" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ------------------------------------------------------- lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "demo" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.demo.id

  # Lifecycle rules on versioned buckets need versioning set up first.
  depends_on = [aws_s3_bucket_versioning.demo]

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "archive-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --------------------------------------------- deny non-TLS requests
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.demo.arn,
      "${aws_s3_bucket.demo.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.demo.id
  policy = data.aws_iam_policy_document.tls_only.json

  # The public access block must exist before a policy is attached.
  depends_on = [aws_s3_bucket_public_access_block.demo]
}

# --------------------------------------------- a sample object
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.demo.id
  key          = "hello.txt"
  content      = "Hello from Terraform! Bucket ${local.bucket_name} in ${var.aws_region}.\n"
  content_type = "text/plain"
}
