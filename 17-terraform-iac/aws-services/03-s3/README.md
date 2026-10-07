# S3 — Simple Storage Service (Storage)

## What is S3?

S3 is **object storage**: you store files ("objects") in containers
("buckets") and retrieve them over HTTPS by key. It is not a filesystem and not
a block device — there are no real directories, no partial in-place edits, and
no mounting as a disk.

- **Durability:** 99.999999999% (11 nines) — data is stored redundantly across
  at least three Availability Zones in standard classes.
- **Scale:** unlimited total storage; a single object can be up to **5 TB**.
- **Consistency:** strong read-after-write consistency for every operation.

The [Terraform demo](../../terraform-s3-demo/) in this session creates and
configures a bucket with everything described below.

## Buckets

A **bucket** is the top-level container.

| Property | Detail |
| --- | --- |
| Name | **Globally unique** across every AWS account; 3–63 chars, lowercase, digits, hyphens, dots |
| Region | Chosen at creation, fixed forever. Data never leaves it unless you replicate it |
| Limit | 10,000 buckets per account by default (raisable) |
| Address | `https://<bucket>.s3.<region>.amazonaws.com/<key>` |

Global uniqueness is why the Terraform demo appends a random suffix —
`devops-hw-dev` is almost certainly already taken by someone.

## Objects

An **object** is the data plus its metadata, identified by a **key**.

```text
s3://devops-hw-dev-a1b2c3d4/logs/2026/10/07/app.log
     └──────── bucket ─────┘└──────────── key ───────┘
```

The `/` in a key is just a character. The console *displays* `logs/2026/` as a
folder, but S3 itself only has a flat namespace of keys; "folders" are
**prefixes**.

Each object has:

- **Key** — its name
- **Value** — the bytes, 0 B to 5 TB
- **Version ID** — when versioning is on
- **Metadata** — system (`Content-Type`, `Last-Modified`, `ETag`) and user-defined (`x-amz-meta-*`)
- **Tags** — up to 10 key/value pairs, usable in IAM and lifecycle rules

Uploads above 100 MB should use **multipart upload**, which is required above
5 GB. The AWS CLI does this automatically.

```bash
aws s3 cp app.log s3://my-bucket/logs/app.log
aws s3 ls s3://my-bucket/logs/
aws s3 sync ./site s3://my-bucket/site --delete
aws s3 presign s3://my-bucket/report.pdf --expires-in 3600   # temporary URL
```

## Storage classes

Price falls as access becomes rarer and retrieval becomes slower or costs more.

| Class | Use for | Retrieval | Min. duration |
| --- | --- | --- | --- |
| **S3 Standard** | Frequently accessed data | Milliseconds | — |
| **S3 Intelligent-Tiering** | Unknown or changing access patterns — moves objects automatically | Milliseconds | — |
| **S3 Standard-IA** | Infrequent access, needs fast retrieval | Milliseconds, per-GB fee | 30 days |
| **S3 One Zone-IA** | Re-creatable, infrequent data — **one AZ only** | Milliseconds, per-GB fee | 30 days |
| **S3 Express One Zone** | Ultra-low-latency, very high request rates | Single-digit ms | — |
| **Glacier Instant Retrieval** | Archives accessed ~once a quarter | Milliseconds | 90 days |
| **Glacier Flexible Retrieval** | Archives, retrieval can wait | Minutes to 12 h | 90 days |
| **Glacier Deep Archive** | Compliance archives, rarely if ever read | 12–48 h | 180 days |

Minimum durations matter: delete a Standard-IA object after 10 days and you
are still billed for 30.

## Versioning

With versioning **enabled**, every overwrite creates a new version and every
delete adds a **delete marker** instead of removing data.

```text
PUT  report.pdf   -> version v1
PUT  report.pdf   -> version v2  (v1 still exists, now "noncurrent")
DEL  report.pdf   -> delete marker on top; v1 and v2 still exist
                     GET report.pdf -> 404, but the data is recoverable
```

- Protects against accidental overwrites, deletions — and ransomware.
- Once enabled it can be **suspended** but never fully turned off.
- Every version is billed, so pair it with a lifecycle rule that expires
  noncurrent versions (the Terraform demo uses 30 days).
- Required for **replication** and **Object Lock**.
- **MFA Delete** can additionally require an MFA code to delete versions.

## Lifecycle policies

Rules that automatically **transition** objects to cheaper classes or
**expire** them, filtered by prefix, tag or size.

```json
{
  "Rules": [{
    "ID": "archive-logs",
    "Status": "Enabled",
    "Filter": { "Prefix": "logs/" },
    "Transitions": [
      { "Days": 30, "StorageClass": "STANDARD_IA" },
      { "Days": 90, "StorageClass": "GLACIER" }
    ],
    "Expiration": { "Days": 365 }
  }]
}
```

```text
day 0           day 30           day 90            day 365
Standard  ───►  Standard-IA ───► Glacier Flexible ───► deleted
```

Two rules every bucket should have, both in the Terraform demo:

1. **Expire noncurrent versions** — otherwise versioning grows cost forever.
2. **Abort incomplete multipart uploads** — failed uploads leave invisible,
   billable parts behind.

## Encryption

**At rest** — since January 2023 every new object is encrypted by default.

| Option | Keys managed by | Notes |
| --- | --- | --- |
| **SSE-S3** | AWS | AES-256. Default. Free, zero effort |
| **SSE-KMS** | AWS KMS — AWS-managed or your customer-managed key | Key usage audited in CloudTrail; key policy adds a second access control; KMS request costs (reduced by *bucket keys*) |
| **DSSE-KMS** | AWS KMS | Two independent layers of encryption, for compliance |
| **SSE-C** | You, sent with every request | AWS never stores the key |
| **Client-side** | You, before upload | S3 only ever sees ciphertext |

**In transit** — enforce HTTPS with a bucket policy that denies any request
where `aws:SecureTransport` is `false`. The Terraform demo does exactly this.

## Bucket policies

A **bucket policy** is a resource-based IAM policy attached to the bucket. It
can grant access to other accounts, services or (rarely) the public, and it
can enforce conditions on everyone.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    },
    {
      "Sid": "AllowCloudFrontRead",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/EDFDVBD6EXAMPLE"
        }
      }
    }
  ]
}
```

**Access control layers**, from broadest to narrowest:

| Layer | Purpose |
| --- | --- |
| **Block Public Access** | Account- and bucket-level kill switch. Overrides any policy that would make data public. **Keep all four settings on.** |
| **Object Ownership = BucketOwnerEnforced** | Disables legacy ACLs entirely |
| **Bucket policy** | Resource-based rules for the whole bucket |
| **IAM policies** | Identity-based rules on users and roles |
| **Access Points** | Named endpoints with their own policies, per application |
| **Presigned URLs** | Time-limited access to one object without credentials |

The infamous "leaky S3 bucket" headlines all come from switching Block Public
Access off and attaching an overly broad policy.

## Common use cases

| Use case | How |
| --- | --- |
| Static website hosting | S3 + CloudFront (Origin Access Control), bucket stays private |
| Backups and disaster recovery | Versioning + lifecycle to Glacier + Cross-Region Replication |
| Data lake | Raw data in S3, queried in place with Athena, Glue, EMR, Redshift Spectrum |
| Application file uploads | Browser uploads directly via presigned URLs, the app server never proxies bytes |
| Log archival | CloudTrail, ALB, VPC Flow Logs delivered to S3 with lifecycle to Glacier |
| Terraform remote state | S3 backend with versioning and encryption, plus locking |
| CI/CD artifacts | Build outputs and release bundles |
| ML datasets and models | Training data in, model artifacts out |
| Compliance / WORM storage | Object Lock in compliance mode |
