# DynamoDB & RDS — Database Services

AWS offers both families of database as managed services. The choice between
them is a choice about **data model and access patterns**, not about which is
"better".

| | DynamoDB | RDS |
| --- | --- | --- |
| Model | NoSQL — key-value and document | Relational — tables, rows, SQL |
| Schema | Only the key is fixed; items vary freely | Fixed schema, enforced |
| Query | By key, designed up-front | Arbitrary SQL, joins, ad-hoc |
| Scaling | Horizontal, automatic, effectively unlimited | Vertical (bigger instance) + read replicas |
| Servers | None — fully serverless | You pick an instance class |
| Latency | Single-digit ms at any scale | Low ms, depends on query and instance |
| Best when | Access patterns are known; huge scale | Relationships, transactions, flexible querying |

---

# DynamoDB

## NoSQL

DynamoDB is a fully managed, serverless **key-value and document** database.
There are no servers to size, no patches, no connection pools to tune. It
delivers consistent single-digit-millisecond latency whether the table holds
a megabyte or a petabyte.

The NoSQL trade-off: you give up joins and ad-hoc queries, and in return get
predictable performance at any scale. **You design the table around your
queries**, not around the shape of your data — the opposite of relational
modelling.

## Tables

A **table** is a collection of items. Unlike SQL, the only thing you declare
up-front is the **primary key**; every other attribute is schemaless.

**Capacity modes:**

| Mode | Billing | Use |
| --- | --- | --- |
| **On-demand** | Per request | Unpredictable or spiky traffic, new apps |
| **Provisioned** | Per RCU/WCU per hour, with auto scaling | Steady, predictable traffic — cheaper |

1 RCU = one strongly consistent 4 KB read/second (or two eventually
consistent). 1 WCU = one 1 KB write/second.

## Items

An **item** is one record — analogous to a row — up to **400 KB**. Items in
the same table can have completely different attributes.

```json
{ "UserId": "u#1001", "OrderId": "o#2026-10-07#001", "Total": 499, "Status": "SHIPPED" }
{ "UserId": "u#1001", "OrderId": "o#2026-10-07#002", "Total": 120, "Coupon": "DIWALI" }
```

## Attributes

An **attribute** is one name/value pair within an item. Types:

| Category | Types |
| --- | --- |
| Scalar | String `S`, Number `N`, Binary `B`, Boolean `BOOL`, Null `NULL` |
| Document | List `L`, Map `M` (nested JSON, up to 32 levels) |
| Set | String Set `SS`, Number Set `NS`, Binary Set `BS` |

## Partition key

The **partition key** (hash key) is hashed to decide **which physical
partition stores the item**. It is the single most important design decision.

- A table with only a partition key needs it to be **unique** per item.
- Choose a **high-cardinality** key (`UserId`, `OrderId`) so load spreads
  evenly. A low-cardinality key (`Status = ACTIVE`) sends most traffic to
  one partition — a **hot partition** — and throttles no matter how much
  capacity the table has.

## Sort key

The optional **sort key** (range key) makes a **composite primary key**:
partition key + sort key must be unique together. Items sharing a partition key
are stored **together, sorted** by the sort key, which enables efficient range
queries.

```text
Partition key: UserId      Sort key: OrderId
──────────────────────────────────────────────────────
u#1001                     o#2026-09-30#004
u#1001                     o#2026-10-07#001
u#1001                     o#2026-10-07#002
u#2002                     o#2026-10-01#001
```

```python
# All of u#1001's orders in October, newest first - one efficient Query
table.query(
    KeyConditionExpression=Key("UserId").eq("u#1001")
        & Key("OrderId").begins_with("o#2026-10"),
    ScanIndexForward=False,
)
```

**Query vs Scan:** a *Query* reads one partition using the key — fast and cheap.
A *Scan* reads the entire table — slow and expensive. A design that needs
Scans for normal traffic is a design that needs rethinking.

**Secondary indexes** add more access patterns:

- **GSI** (Global Secondary Index) — a different partition and sort key,
  creatable any time.
- **LSI** (Local Secondary Index) — same partition key, different sort key;
  must be defined at table creation.

Other features: **DynamoDB Streams** (change data capture, often triggering
Lambda), **TTL** (automatic expiry of items), **Global Tables** (multi-region,
multi-active replication), **PITR** (point-in-time recovery for 35 days),
**DAX** (in-memory cache, microsecond reads), and ACID **transactions**
across up to 100 items.

## DynamoDB use cases

| Use case | Why DynamoDB fits |
| --- | --- |
| Shopping carts, user sessions | Key lookups, TTL for expiry, massive scale |
| Gaming leaderboards and player state | Low-latency, high write throughput |
| IoT and telemetry ingestion | Unlimited write scale, TTL for retention |
| Serverless backends (Lambda + API Gateway) | No connections to manage, scales to zero |
| Terraform state locking | Simple key-value lock table |
| Ad tech, real-time bidding | Consistent ms latency under heavy load |
| Event-driven architectures | DynamoDB Streams feeding Lambda |

---

# RDS — Relational Database Service

## Relational database

RDS runs **relational databases** — data in tables with fixed columns, linked
by foreign keys, queried with **SQL**, with full **ACID** transactions.

What "managed" means in practice:

| AWS handles | You handle |
| --- | --- |
| Provisioning and hardware | Schema design and query tuning |
| OS and engine patching (in your maintenance window) | Choosing the instance class and storage |
| Automated backups and point-in-time recovery | Users, grants and application access |
| Multi-AZ failover | Parameter group tuning |
| Monitoring metrics | Deciding when to scale |

You do **not** get OS or SSH access to the database host.

## Supported engines

| Engine | Notes |
| --- | --- |
| **Amazon Aurora** (MySQL- and PostgreSQL-compatible) | AWS-built storage layer: 6 copies across 3 AZs, up to 15 low-lag replicas, fast failover, Aurora Serverless v2 |
| **PostgreSQL** | Open source, feature-rich, extensions such as PostGIS |
| **MySQL** | The most widely used open-source database |
| **MariaDB** | Community fork of MySQL |
| **Oracle** | Bring-your-own-license or license-included |
| **Microsoft SQL Server** | Express, Web, Standard, Enterprise editions |
| **IBM Db2** | Added in 2023 |

## DB instances

A **DB instance** is the isolated database environment — the compute running
one engine. You choose:

- **Instance class** — `db.t4g.micro` (burstable, dev/test), `db.m7g.large`
  (general purpose), `db.r7g.xlarge` (memory-optimised, most production
  databases).
- **Storage** — `gp3` (general purpose), `io2` (provisioned IOPS for
  heavy workloads). **Storage autoscaling** grows the volume automatically.
- **Parameter group** — engine configuration (`max_connections`,
  `work_mem`…).
- **Option group** — engine add-ons (e.g. Oracle TDE).

Scaling the instance class up is a modification that causes a brief outage
(shorter with Multi-AZ, since it fails over to the already-upgraded standby).

## Security

| Layer | Control |
| --- | --- |
| **Network** | Place in **private DB subnets** via a DB subnet group. Set `publicly_accessible = false`. Security Group allows the DB port **only from the app's Security Group** |
| **Encryption at rest** | KMS, chosen **at creation** — an unencrypted DB can only be encrypted by snapshot → copy-encrypted → restore. Covers storage, backups, snapshots and replicas |
| **Encryption in transit** | TLS; enforce it with `rds.force_ssl = 1` (PostgreSQL) or `require_secure_transport` (MySQL) |
| **Authentication** | Master password stored in **Secrets Manager** with automatic rotation, or **IAM database authentication** with short-lived tokens |
| **Auditing** | Engine audit logs exported to CloudWatch; all API calls in CloudTrail |
| **Protection** | Deletion protection; a final snapshot on delete |

## Backups

**Automated backups:**

- A daily snapshot during the backup window plus **transaction logs every 5
  minutes**.
- **Point-in-time recovery (PITR)** to any second within the retention period
  (1–35 days).
- A restore always creates a **new** DB instance with a new endpoint — it
  never overwrites the existing one.

**Manual snapshots:**

- Taken on demand, kept until you delete them, even after the instance is
  gone.
- Can be **copied across regions and shared across accounts** for disaster
  recovery.

**AWS Backup** can manage both centrally with policies.

## Multi-AZ

**High availability**, not scaling.

```text
         app ─► DB endpoint (DNS name, never changes)
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
   Primary (AZ-a)  ══sync══►  Standby (AZ-b)
   serves traffic              serves NOTHING, waits
```

- **Synchronous** replication to a standby in another AZ — no committed data
  is lost on failover.
- **Automatic failover** in roughly 60–120 seconds on instance failure, AZ
  outage, or during maintenance. The DNS endpoint is repointed; the app just
  reconnects.
- The classic standby **does not serve reads**. (*Multi-AZ DB clusters* — two
  readable standbys — and Aurora replicas do.)

## Read replicas

**Read scaling**, not HA.

```text
   writes ─► Primary ──async──► Read replica 1  ◄── reads
                     ──async──► Read replica 2  ◄── reads
                     ──async──► Read replica (another region) ◄── DR / local reads
```

- **Asynchronous** replication — replicas can lag behind the primary.
- Each replica has **its own endpoint**; the application must send reads there.
- Up to 15 replicas (Aurora and most engines); can be **cross-region**.
- Can be **promoted** to a standalone primary — a manual DR mechanism.

### Multi-AZ vs read replicas

| | Multi-AZ | Read replica |
| --- | --- | --- |
| Purpose | High availability | Read scalability |
| Replication | Synchronous | Asynchronous |
| Serves reads | No (classic) | Yes |
| Failover | Automatic | Manual promotion |
| Region | Same region | Same or different region |
| Endpoint | Same endpoint | Separate endpoint |

Production databases commonly use **both**.

## RDS use cases

| Use case | Why RDS fits |
| --- | --- |
| Web and mobile app backends | Relational data, joins, transactions |
| E-commerce orders, payments, inventory | ACID transactions are non-negotiable |
| ERP, CRM, financial systems | Complex relational schemas, reporting |
| Migrating an on-premises database | Same engine, managed — lift-and-shift with AWS DMS |
| Multi-tenant SaaS | Mature schemas, row-level security in PostgreSQL |
| Reporting and analytics on OLTP data | SQL, with reads offloaded to replicas |

## Choosing between them

```text
Do you need joins, ad-hoc queries, complex transactions or reporting?
   └── yes ─► RDS (Aurora if you need scale and fast failover)

Are access patterns known, simple, key-based — and scale huge or spiky?
   └── yes ─► DynamoDB

Serverless architecture with no capacity management?
   └── DynamoDB (or Aurora Serverless v2 if you need SQL)
```
