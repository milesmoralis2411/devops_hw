# OUTPUTS: values printed after apply and readable by other tooling
# ("terraform output -json"), or by other Terraform configurations.

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the web Security Group"
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "Open this in a browser once the instance has booted"
  value       = "http://${aws_instance.web.public_dns}"
}

output "s3_bucket" {
  description = "Name of the assets bucket"
  value       = aws_s3_bucket.assets.id
}

output "ssm_connect_command" {
  description = "Shell into the instance without SSH"
  value       = "aws ssm start-session --target ${aws_instance.web.id} --region ${var.aws_region}"
}
