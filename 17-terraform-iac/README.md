# Session 18 — Terraform & Infrastructure as Code

| Task | Folder | Contents |
| --- | --- | --- |
| 1. Terraform S3 demo | [terraform-s3-demo/](terraform-s3-demo/) | `main.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `terraform.tfvars`, full workflow from `init` to `destroy`, executed |
| 2. AWS services research | [aws-services/](aws-services/) | One README per service |

```text
17-terraform-iac/
├── terraform-s3-demo/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars
│   ├── README.md
│   └── EVIDENCE.md
└── aws-services/
    ├── 01-iam/README.md            Governance — users, groups, roles, policies, least privilege
    ├── 02-ec2/README.md            Compute — AMIs, instance types, key pairs, SGs, EBS, lifecycle
    ├── 03-s3/README.md             Storage — buckets, objects, classes, versioning, lifecycle, encryption
    ├── 04-vpc/README.md            Networking — CIDR, subnets, routing, IGW, NAT, SG vs NACL
    └── 05-dynamodb-rds/README.md   Databases — NoSQL keys and indexes; RDS engines, Multi-AZ, replicas
```

## Infrastructure as Code in one paragraph

Infrastructure as Code means describing servers, networks and storage in
version-controlled text files instead of clicking through a console.
Terraform's files are **declarative**: you describe the *end state* ("a
versioned, encrypted bucket exists"), and Terraform works out the API calls
needed to get there from whatever exists now. That gives you review through
pull requests, reproducible environments (dev, staging and prod from the same
code), a history of every change, and drift detection — `terraform plan` shows
when reality no longer matches the code.

## Core Terraform concepts

| Concept | Meaning |
| --- | --- |
| **Provider** | A plugin that talks to one API — `hashicorp/aws`, `hashicorp/random`, `hashicorp/kubernetes` |
| **Resource** | Something Terraform creates and manages — `aws_s3_bucket` |
| **Data source** | Something Terraform only *reads* — `aws_ami`, `aws_iam_policy_document` |
| **Variable** | An input, with a type, a default and validation rules |
| **Output** | A value exported after apply |
| **Local** | A named expression, reused inside the configuration |
| **State** | Terraform's mapping from code to real resource IDs |
| **Plan** | The computed diff between code and reality |
| **Module** | A reusable package of `.tf` files |
| **Backend** | Where the state is stored — local file, S3, Terraform Cloud |
