output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "eks_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.id
}

output "github_ci_role_arn" {
  description = "Use in the workflow: aws-actions/configure-aws-credentials role-to-assume"
  value       = aws_iam_role.github_ci.arn
}
