aws_region         = "ap-south-1"
project_name       = "yatri"
environment        = "dev"
vpc_cidr           = "10.20.0.0/16"
public_subnet_cidr = "10.20.1.0/24"
instance_type      = "t3.micro"
allowed_http_cidrs = ["0.0.0.0/0"]
allowed_ssh_cidrs  = [] # no SSH - use SSM Session Manager
