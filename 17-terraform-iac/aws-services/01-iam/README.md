# IAM — Identity and Access Management (Governance)

## What is IAM?

IAM is the AWS service that answers two questions for every single API call
made against an AWS account:

1. **Authentication** — *who* is making this request?
2. **Authorization** — *is that identity allowed* to do this, on this resource?

It is global (not tied to a region) and free. Every other AWS service relies on
it — there is no way to call S3, EC2 or anything else without IAM evaluating
the request first.

```text
API call  ──►  who are you?  ──►  which policies apply?  ──►  Allow / Deny
               (authenticate)      (collect & evaluate)
```

## The root user

The email address that created the account is the **root user**. It has
unrestricted access that no policy can limit. Best practice is to:

- enable MFA on it immediately,
- delete any root access keys,
- lock the credentials away and never use it for daily work.

Only a handful of tasks genuinely need root (changing the support plan, closing
the account, restoring a bucket policy that locked everyone out).

## Users

An **IAM user** is a long-lived identity representing one person or one
application. It can have:

- a **console password** (for humans, plus MFA), and/or
- up to two **access keys** (`AKIA…` key ID + secret) for programmatic access.

```bash
aws iam create-user --user-name alice
aws iam create-login-profile --user-name alice --password '...' --password-reset-required
aws iam create-access-key --user-name ci-bot
```

Users have **permanent** credentials, which is exactly their weakness — a
leaked access key works until someone notices and rotates it. Modern guidance
is to avoid IAM users for humans entirely (use IAM Identity Center / SSO) and
avoid them for workloads (use roles).

## Groups

A **group** is a collection of users that share permissions. Attach policies
to the group, add users to it, and they inherit everything.

```text
Group: Developers   ─ policy: PowerUserAccess
   ├── alice
   └── bob

Group: Auditors     ─ policy: ReadOnlyAccess, SecurityAudit
   └── carol
```

Groups cannot be nested, cannot be a principal in a resource policy, and
cannot log in. They exist purely to manage permissions at scale: onboarding
is "add to group", offboarding is "remove from group".

## Roles

A **role** is an identity with permissions but **no long-term credentials**.
Instead, something *assumes* the role and receives **temporary credentials**
from AWS STS that expire automatically (15 minutes to 12 hours).

Every role has two policies:

| Policy | Answers |
| --- | --- |
| **Trust policy** | *Who* is allowed to assume this role |
| **Permissions policy** | *What* the role can do once assumed |

A trust policy letting EC2 instances assume a role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

Who assumes roles:

- **AWS services** — an EC2 instance profile, a Lambda execution role, an EKS
  Pod via IRSA / Pod Identity.
- **Other accounts** — cross-account access without sharing keys.
- **Federated users** — SSO logins, and GitHub Actions via OIDC.
- **IAM users** — for privilege elevation ("break-glass" admin access).

Roles are the right answer for almost every non-human access need. GitHub
Actions assuming a role through OIDC, for instance, means there is no AWS
secret stored in GitHub at all.

## Policies

A **policy** is a JSON document listing permissions. Each statement has:

| Element | Meaning |
| --- | --- |
| `Effect` | `Allow` or `Deny` |
| `Action` | API operations, e.g. `s3:GetObject`, `ec2:*` |
| `Resource` | ARNs the statement applies to |
| `Condition` | Optional — when it applies (IP, MFA, tags, time, TLS…) |
| `Principal` | Only in resource-based policies — who it applies to |

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::devops-hw-dev-a1b2c3d4",
        "arn:aws:s3:::devops-hw-dev-a1b2c3d4/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "true" }
      }
    }
  ]
}
```

**Types of policy:**

| Type | Attached to | Example |
| --- | --- | --- |
| AWS-managed | Users, groups, roles | `ReadOnlyAccess`, `AmazonS3FullAccess` |
| Customer-managed | Users, groups, roles | Your own reusable policy, versioned |
| Inline | One identity only | Deleted along with that identity |
| Resource-based | The resource itself | S3 bucket policy, KMS key policy, SQS queue policy |
| Permissions boundary | A user or role | Sets the *maximum* permissions it can ever have |
| SCP (Organizations) | An account or OU | Guardrail across whole accounts |

## Permissions — how a request is evaluated

```text
1. Start with an implicit DENY for everything.
2. Is there an explicit DENY anywhere (SCP, boundary, identity, resource)?
       yes  ─►  DENIED.  An explicit deny always wins.
3. Does an SCP / permissions boundary allow it?  (if they exist)
       no   ─►  DENIED.
4. Does an identity policy or resource policy ALLOW it?
       yes  ─►  ALLOWED.
       no   ─►  DENIED   (the implicit deny from step 1 stands)
```

Three rules to remember:

- **Default deny** — nothing is allowed unless something says so.
- **Explicit deny wins** — a single `Deny` overrides any number of `Allow`s.
- **Boundaries and SCPs only restrict** — they never grant anything on their own.

## Least privilege

Grant only the permissions required for the task, on only the resources
required, for only as long as required.

| Instead of | Use |
| --- | --- |
| `"Action": "*"` | The specific actions, e.g. `s3:GetObject` |
| `"Resource": "*"` | Exact ARNs |
| `AdministratorAccess` for a CI job | A role scoped to the one bucket and one ECR repo it uses |
| Permanent access keys | Roles with temporary credentials |
| Guessing what is needed | **IAM Access Analyzer** policy generation from CloudTrail activity |

Least privilege limits the blast radius: a compromised identity can only do
what that identity was allowed to do.

## IAM best practices

1. **Lock down root** — MFA on, no access keys, not used day-to-day.
2. **Use federation / IAM Identity Center for humans** — no IAM users with
   passwords where avoidable.
3. **Use roles for workloads** — EC2 instance profiles, Lambda execution
   roles, IRSA for EKS, OIDC for CI/CD.
4. **Require MFA**, especially for privileged actions.
5. **Apply least privilege**, and tighten over time with Access Analyzer.
6. **Prefer managed policies over inline** so they are reusable and versioned.
7. **Rotate any long-lived keys** and delete the unused ones (the credential
   report shows key age and last use).
8. **Use conditions** — require TLS, restrict source IPs or VPC endpoints,
   require tags.
9. **Use permissions boundaries** when delegating the ability to create roles.
10. **Turn on CloudTrail** so every IAM action is auditable.
11. **Never commit access keys to Git** — secret scanning (see Session 17)
    exists precisely because this keeps happening.

## Common use cases

| Need | IAM solution |
| --- | --- |
| Developers need console access | IAM Identity Center + permission sets, MFA required |
| EC2 app reads from S3 | Instance profile role with `s3:GetObject` on one bucket |
| Lambda writes to DynamoDB | Lambda execution role scoped to one table |
| GitHub Actions deploys to AWS | OIDC identity provider + role trusting the repo, no stored secrets |
| A Pod in EKS needs AWS access | IRSA or EKS Pod Identity |
| Another AWS account needs read access | Cross-account role with a trust policy naming that account |
| Auditors need read-only access | `ReadOnlyAccess` + `SecurityAudit` via a group or permission set |
| Stop anyone disabling CloudTrail | SCP with an explicit `Deny` on `cloudtrail:StopLogging` |
| Terraform runs in CI | A dedicated role with only the permissions the plan needs |
