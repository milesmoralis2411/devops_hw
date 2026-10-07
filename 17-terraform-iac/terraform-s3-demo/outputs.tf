output "bucket_name" {
  description = "Name of the created bucket"
  value       = aws_s3_bucket.demo.id
}

output "bucket_arn" {
  description = "ARN of the bucket, for IAM policies"
  value       = aws_s3_bucket.demo.arn
}

output "bucket_region" {
  description = "Region the bucket lives in"
  value       = aws_s3_bucket.demo.region
}

output "bucket_domain_name" {
  description = "Regional domain name of the bucket"
  value       = aws_s3_bucket.demo.bucket_regional_domain_name
}

output "versioning_status" {
  description = "Whether versioning is on"
  value       = aws_s3_bucket_versioning.demo.versioning_configuration[0].status
}

output "sample_object_uri" {
  description = "S3 URI of the uploaded sample object"
  value       = "s3://${aws_s3_bucket.demo.id}/${aws_s3_object.readme.key}"
}
