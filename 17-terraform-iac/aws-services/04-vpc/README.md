# VPC — Virtual Private Cloud (Networking)

## What is a VPC?

A **VPC** is your own logically isolated network inside an AWS region. You
choose its IP range, carve it into subnets, decide how traffic is routed, and
control what can reach what. Nothing gets in or out unless you build a path
for it.

- A VPC lives in **one region** and spans **all of its Availability Zones**.
- Each subnet lives in **exactly one AZ**.
- Every account gets a **default VPC** per region, with public subnets in
  every AZ — convenient for experiments, unsuitable for production.

[Session 19](../../../18-cloud-terraform-in-action/) builds a VPC, subnets,
routing and Security Groups with Terraform.

```text
Region ap-south-1 ─────────────────────────────────────────────────────────────
│ VPC 10.0.0.0/16                                                             │
│                                                                             │
│   AZ ap-south-1a                         AZ ap-south-1b                     │
│  ┌──────────────────────────┐           ┌──────────────────────────┐        │
│  │ public  10.0.1.0/24      │           │ public  10.0.2.0/24      │        │
│  │  ALB, NAT Gateway        │           │  ALB, NAT Gateway        │        │
│  └──────────────────────────┘           └──────────────────────────┘        │
│  ┌──────────────────────────┐           ┌──────────────────────────┐        │
│  │ private 10.0.11.0/24     │           │ private 10.0.12.0/24     │        │
│  │  EC2 / EKS nodes         │           │  EC2 / EKS nodes         │        │
│  └──────────────────────────┘           └──────────────────────────┘        │
│  ┌──────────────────────────┐           ┌──────────────────────────┐        │
│  │ db      10.0.21.0/24     │           │ db      10.0.22.0/24     │        │
│  │  RDS primary             │           │  RDS standby             │        │
│  └──────────────────────────┘           └──────────────────────────┘        │
│                                                                             │
│                 Internet Gateway  ◄──►  internet                            │
───────────────────────────────────────────────────────────────────────────────
```

## CIDR

**Classless Inter-Domain Routing** notation describes an IP range as
`base-address/prefix-length`. The prefix length is how many leading bits are
fixed; the rest are available for hosts.

| CIDR | Fixed bits | Addresses | Typical use |
| --- | --- | --- | --- |
| `10.0.0.0/16` | 16 | 65,536 | A whole VPC (the largest AWS allows) |
| `10.0.1.0/24` | 24 | 256 | One subnet |
| `10.0.1.0/28` | 28 | 16 | The smallest subnet AWS allows |
| `10.0.1.5/32` | 32 | 1 | A single host, e.g. in a Security Group rule |
| `0.0.0.0/0` | 0 | all | "Anywhere" — the default route |

**Formula:** addresses = 2^(32 − prefix). A `/24` is 2^8 = 256.

**AWS reserves 5 addresses in every subnet.** In `10.0.1.0/24`:

| Address | Reserved for |
| --- | --- |
| `10.0.1.0` | Network address |
| `10.0.1.1` | VPC router |
| `10.0.1.2` | Amazon DNS |
| `10.0.1.3` | Future use |
| `10.0.1.255` | Broadcast (unsupported, but reserved) |

So a `/24` gives **251** usable IPs, and a `/28` only **11**.

**Planning rules:**

- Use private (RFC 1918) ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- Never overlap CIDRs between VPCs you might ever peer, or with your office
  or data-centre network — overlapping ranges cannot be routed together.
- Size generously. EKS gives every Pod a VPC IP, so a `/24` per AZ runs out
  quickly.

## Subnets

A **subnet** is a slice of the VPC CIDR, pinned to one AZ. What makes a subnet
"public" or "private" is **not** a property of the subnet itself — it is
entirely determined by its **route table**.

Spreading subnets across at least two AZs is what makes an architecture highly
available: an AZ outage takes out one set of subnets, not the application.

## Route tables

A **route table** is a set of rules deciding where traffic leaving a subnet
goes. Each subnet is associated with exactly one route table; the most
specific matching route (longest prefix) wins.

**Public subnet route table:**

| Destination | Target |
| --- | --- |
| `10.0.0.0/16` | `local` |
| `0.0.0.0/0` | `igw-0abc…` (Internet Gateway) |

**Private subnet route table:**

| Destination | Target |
| --- | --- |
| `10.0.0.0/16` | `local` |
| `0.0.0.0/0` | `nat-0def…` (NAT Gateway) |

The `local` route is created automatically and cannot be removed — it is why
every subnet in a VPC can reach every other subnet by default.

## Internet Gateway (IGW)

A horizontally scaled, highly available gateway that connects the VPC to the
internet. One per VPC.

For an instance to be reachable from the internet, **all four** must hold:

1. An IGW is attached to the VPC.
2. The subnet's route table sends `0.0.0.0/0` to the IGW.
3. The instance has a **public IP** or Elastic IP.
4. Its Security Group and the subnet's NACL allow the traffic.

Miss any one and the instance is unreachable — the most common "why can't I
SSH in" root cause.

The IGW also performs the 1:1 NAT between an instance's private IP and its
public IP.

## NAT Gateway

Lets instances in **private** subnets make **outbound** connections (OS
updates, pulling images, calling external APIs) while remaining unreachable
from the internet.

```text
private EC2 ──► NAT Gateway (in a public subnet, with an Elastic IP) ──► IGW ──► internet
                  │
                  └── replies come back through the NAT; nothing can initiate inbound
```

- Lives in a **public** subnet; private route tables point `0.0.0.0/0` at it.
- Managed by AWS — scales automatically, no patching.
- Zonal: deploy **one per AZ** for high availability, or a single AZ failure
  cuts outbound access for every private subnet.
- **Cost:** hourly charge plus per-GB processing. It is often the single most
  surprising line on a small AWS bill. **VPC Gateway Endpoints** for S3 and
  DynamoDB are free and keep that traffic off the NAT entirely.

## Security Groups

**Stateful** firewalls attached to network interfaces (instances, RDS, Lambda
in a VPC, load balancers).

- **Allow rules only.**
- **Stateful** — return traffic is automatically allowed.
- Can reference other Security Groups as a source.
- All rules are evaluated together; there is no rule order.

## Network ACLs

**Stateless** firewalls attached to **subnets**.

- Both **allow and deny** rules.
- **Numbered rules evaluated in order**, lowest first; the first match wins.
- **Stateless** — return traffic must be allowed explicitly, which means
  opening the **ephemeral port range** (`1024-65535`) for responses.
- The default NACL allows everything; custom NACLs deny everything until rules
  are added.

### Security Group vs NACL

| | Security Group | Network ACL |
| --- | --- | --- |
| Applies to | Network interface (instance level) | Subnet |
| State | **Stateful** | **Stateless** |
| Rules | Allow only | Allow **and** Deny |
| Evaluation | All rules together | In numeric order, first match wins |
| Return traffic | Automatic | Must be explicitly allowed |
| Typical use | Primary, fine-grained control | Coarse guardrail, e.g. blocking a bad IP range |

```text
internet ─► IGW ─► route table ─► [ NACL: subnet boundary ] ─► [ SG: instance ] ─► EC2
```

## Public vs private subnet

| | Public subnet | Private subnet |
| --- | --- | --- |
| Default route | `0.0.0.0/0 → Internet Gateway` | `0.0.0.0/0 → NAT Gateway` (or none) |
| Inbound from internet | Possible (with public IP + SG) | **Impossible** |
| Outbound to internet | Direct | Via NAT Gateway |
| Instances get public IPs | Usually | Never |
| What lives here | Load balancers, NAT Gateways, bastions | App servers, EKS nodes, databases, caches |

The standard pattern is a **three-tier VPC**: only load balancers in public
subnets, application compute in private subnets, and databases in isolated
private subnets with no route to the internet at all.

## Other VPC building blocks

| Component | Purpose |
| --- | --- |
| **VPC Endpoints** | Private access to AWS services without the internet. *Gateway* type (S3, DynamoDB) is free; *Interface* type (PrivateLink) for most others |
| **VPC Peering** | Private routing between two VPCs; non-transitive |
| **Transit Gateway** | Hub-and-spoke routing across many VPCs and on-premises networks |
| **Site-to-Site VPN / Direct Connect** | Connect a data centre over an encrypted tunnel or a dedicated line |
| **VPC Flow Logs** | Record accepted and rejected traffic for troubleshooting and security analysis |
| **Egress-only IGW** | The IPv6 equivalent of a NAT Gateway |
