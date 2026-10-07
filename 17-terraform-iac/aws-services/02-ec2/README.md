# EC2 — Elastic Compute Cloud (Compute)

## What is EC2?

EC2 provides resizable virtual machines — **instances** — in the AWS cloud.
You choose the operating system, CPU, memory, storage and networking, and pay
for the time the instance runs. It is Infrastructure-as-a-Service: AWS manages
the physical hardware and the hypervisor (Nitro); you manage everything from
the OS upward.

| AWS manages | You manage |
| --- | --- |
| Data centre, hardware, hypervisor | Operating system and its patches |
| Physical network | Applications, runtime, data |
| | Security Group rules, IAM role |
| | Backups (EBS snapshots) |

This is the **shared responsibility model** in its most concrete form.

## AMI — Amazon Machine Image

An **AMI** is the template an instance boots from. It contains:

- a root volume snapshot (OS + any pre-installed software),
- launch permissions (who may use it),
- a block device mapping (which volumes to attach at launch).

Sources:

| Source | Example |
| --- | --- |
| AWS-provided | Amazon Linux 2023, Ubuntu, Windows Server |
| AWS Marketplace | Vendor images with licensed software |
| Community | Public AMIs shared by anyone — vet carefully |
| Your own | Built with Packer, or "Create image" from a configured instance |

AMIs are **regional** — an AMI ID in `ap-south-1` does not exist in
`us-east-1` (copy it across). Baking a "golden AMI" with the app pre-installed
makes instances boot ready to serve, which matters for fast autoscaling.

```hcl
# Terraform: look up the latest Amazon Linux 2023 AMI instead of hard-coding an ID
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

## Instance types

Named `<family><generation><attributes>.<size>`, e.g. **`m7g.large`** =
general-purpose (m), 7th gen, Graviton/ARM (g), large.

| Family | Optimised for | Examples | Use |
| --- | --- | --- | --- |
| **T** | Burstable general purpose | `t3.micro`, `t4g.small` | Dev/test, low steady load, small web apps |
| **M** | Balanced general purpose | `m7i.large`, `m7g.xlarge` | App servers, most backends |
| **C** | Compute | `c7i.2xlarge` | Batch, encoding, high-traffic web, gaming |
| **R / X** | Memory | `r7g.4xlarge`, `x2idn` | In-memory caches, large databases |
| **I / D** | Storage (local NVMe) | `i4i.xlarge` | NoSQL, data warehousing |
| **P / G / Inf / Trn** | Accelerated (GPU / ML chips) | `g5.xlarge`, `p5` | ML training/inference, graphics |

Size scales roughly linearly: `large` → `xlarge` → `2xlarge` doubles vCPU and
memory each step.

**T-family credits:** burstable instances earn CPU credits while idle and
spend them under load. A `t3.micro` pinned at 100% CPU runs out of credits
and is throttled to its baseline — or, in `unlimited` mode, bills extra.

**Pricing models:**

| Model | Discount | Commitment | Good for |
| --- | --- | --- | --- |
| On-Demand | — | None | Unpredictable or short workloads |
| Savings Plans / Reserved | up to ~72% | 1 or 3 years | Steady baseline load |
| Spot | up to ~90% | None, but can be reclaimed with 2 min notice | Fault-tolerant batch, CI runners, stateless workers |
| Dedicated Hosts | — | Varies | Licensing or compliance needs |

## Key pairs

A **key pair** is an SSH public/private key used to log in to Linux instances
(or decrypt the Windows administrator password).

- AWS stores only the **public** key and injects it into
  `~/.ssh/authorized_keys` at first boot.
- You download the **private** key **once**. Lose it and you cannot get it
  back.

```bash
aws ec2 create-key-pair --key-name demo-key --key-type ed25519 \
  --query KeyMaterial --output text > demo-key.pem
chmod 400 demo-key.pem
ssh -i demo-key.pem ec2-user@<public-ip>
```

**Modern alternative:** AWS Systems Manager **Session Manager** gives a shell
with no SSH key, no open port 22 and full audit logging. EC2 Instance Connect
pushes a short-lived key per session. Both are preferable to long-lived keys.

## Security Groups

A **Security Group** is a **stateful** virtual firewall attached to an
instance's network interface.

- **Allow rules only** — there is no "deny" rule. Anything not allowed is
  denied.
- **Stateful** — if an inbound request is allowed, its response is
  automatically allowed out, and vice versa.
- Default: **all inbound denied, all outbound allowed**.
- Rules can reference **another Security Group** instead of an IP range — the
  idiomatic way to say "the app tier may talk to the DB tier".

```text
sg-web   inbound: 443 from 0.0.0.0/0
                  80  from 0.0.0.0/0
sg-app   inbound: 8080 from sg-web          <- SG reference, not an IP
sg-db    inbound: 5432 from sg-app
```

The classic mistake is `22` open to `0.0.0.0/0` — bots find it within minutes.

## EBS — Elastic Block Store

**EBS** volumes are network-attached block storage for instances — virtual
hard disks that persist independently of the instance.

| Volume type | Media | Use |
| --- | --- | --- |
| `gp3` | SSD | Default. Baseline 3,000 IOPS, independently tunable |
| `io2` Block Express | SSD | High-IOPS databases, up to 256,000 IOPS |
| `st1` | HDD | Throughput-heavy sequential reads (big data, logs) |
| `sc1` | HDD | Cold, rarely accessed data — cheapest |

Key facts:

- An EBS volume lives in **one Availability Zone** and attaches only to
  instances in that AZ.
- **Snapshots** are incremental backups stored in S3; they can be copied to
  other regions and used to create new volumes or AMIs.
- `DeleteOnTermination` is `true` for the root volume by default — terminate
  the instance and the disk goes with it.
- Enable **encryption by default** for the account; it is free and uses KMS.

**Instance store** is the alternative: physically attached NVMe disks that are
very fast but **ephemeral** — data is lost on stop or termination.

## Public vs private IP

| | Private IP | Public IP | Elastic IP |
| --- | --- | --- | --- |
| Reachable from | Inside the VPC (and peered / VPN networks) | The internet | The internet |
| Assigned | Always, from the subnet CIDR | Optionally, at launch, in a public subnet | Explicitly allocated to your account |
| Survives stop/start | **Yes** | **No** — a new one on every start | **Yes** |
| Cost | Free | Charged per hour (since Feb 2024) | Charged per hour |

The instance's OS never actually sees its public IP — the Internet Gateway
performs 1:1 NAT between the public IP and the private IP. Run `ip addr` on an
instance and you see only the private address.

Production servers usually sit in **private subnets** with no public IP at
all, behind a load balancer, reaching out via a NAT Gateway.

## Instance lifecycle

```text
               launch
                 │
                 ▼
             ┌────────┐
             │pending │
             └───┬────┘
                 ▼
  reboot   ┌──────────┐   stop    ┌────────┐         ┌─────────┐
 ┌────────►│ running  ├──────────►│stopping├────────►│ stopped │
 └─────────┤          │◄──────────┴────────┘  start  └────┬────┘
           └────┬─────┘                                   │
                │ terminate                               │ terminate
                ▼                                         ▼
          ┌────────────┐                           ┌────────────┐
          │shutting-down├─────────────────────────►│ terminated │
          └────────────┘                           └────────────┘
```

| State | Billed for compute? | Notes |
| --- | --- | --- |
| `pending` | No | Booting |
| `running` | **Yes** | Per second (Linux, 60 s minimum) |
| `stopping` / `stopped` | No | EBS storage still billed; instance-store data **lost**; public IP released |
| `rebooting` | Yes | Same host, keeps IPs and instance store |
| `terminated` | No | Gone permanently. Root EBS deleted by default |
| `hibernated` | No | RAM saved to the EBS root volume, resumes faster |

Enable **termination protection** on anything you would not want deleted by a
mis-click or a mis-scoped `terraform destroy`.

## Common use cases

| Use case | Typical setup |
| --- | --- |
| Web / application servers | Auto Scaling Group of `m7`/`c7` instances behind an ALB, in private subnets |
| Self-managed databases | `r7` or `i4i` instances with `io2` volumes |
| CI/CD build agents | Spot instances that scale to zero when idle |
| Batch / HPC | `c7` or `hpc7` on Spot, orchestrated by AWS Batch |
| ML training & inference | `p5`, `g5`, `inf2`, `trn1` |
| Kubernetes worker nodes | EKS managed node groups or Karpenter |
| Bastion / jump host | One `t4g.nano` — or better, none at all: use SSM Session Manager |
| Lift-and-shift migrations | Existing VMs moved as-is with AWS Application Migration Service |
