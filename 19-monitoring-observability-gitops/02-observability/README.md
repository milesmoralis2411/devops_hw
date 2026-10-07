# Observability

## Monitoring vs observability

**Monitoring** asks questions you decided on in advance: *is CPU above 80%? is
the error rate above 1%?* It tells you **that** something is wrong.

**Observability** is the property of a system that lets you ask questions you
did **not** anticipate — *why are checkout requests from one region slow, but
only for users on the new app version?* — using the data the system already
emits. It tells you **why**.

| | Monitoring | Observability |
| --- | --- | --- |
| Questions | Known in advance | Arbitrary, asked after the fact |
| Answers | "Something is broken" | "This is what is broken, and why" |
| Built from | Dashboards and alerts on chosen metrics | Rich, correlated metrics, logs and traces |
| Suits | Known failure modes | Unknown failure modes ("unknown unknowns") |

Monitoring is a subset of observability, not an alternative to it.

## The three pillars

### 1. Metrics

**Numeric measurements over time**, aggregated and cheap to store.

```text
http_requests_total{method="GET",route="/api/orders",status="500"}  1027  @ 1696680000
```

- **Strengths:** cheap, fast to query, ideal for dashboards, trends and
  alerting. Volume does not grow with traffic — a counter is one number
  whether it saw ten requests or ten million.
- **Weakness:** aggregated, so the detail of any individual request is gone.
  A metric says *"p99 latency doubled"*, not *which* request was slow.
- **Types (Prometheus):** `counter` (only goes up — requests, errors),
  `gauge` (up and down — memory, queue depth), `histogram` (buckets —
  latency distributions), `summary` (client-side quantiles).

Two widely used methods for choosing *which* metrics:

| Method | For | Signals |
| --- | --- | --- |
| **RED** | Services / requests | **R**ate, **E**rrors, **D**uration |
| **USE** | Resources (CPU, disk, network) | **U**tilisation, **S**aturation, **E**rrors |

Google SRE's **four golden signals** combine them: latency, traffic, errors,
saturation.

### 2. Logs

**Timestamped, discrete records of events.**

```json
{"ts":"2026-10-07T14:59:03Z","level":"error","service":"orders","trace_id":"4bf92f3577b34da6","user":"u#1001","msg":"payment declined","code":"CARD_EXPIRED"}
```

- **Strengths:** the richest detail — exactly what happened, with full
  context. The first thing most engineers reach for when debugging.
- **Weaknesses:** expensive at volume (storage grows linearly with traffic),
  and hard to correlate across services without a shared ID.
- **Best practice:** log **structured JSON**, not free text, so logs are
  queryable fields rather than strings to grep. Include a `trace_id` in every
  line — it is what links a log to a trace. Never log secrets or personal data.

### 3. Traces

**The end-to-end path of a single request** as it crosses services.

```text
trace_id 4bf92f3577b34da6                                     total 812 ms
│
├─ api-gateway      GET /checkout                    ███████████████████  812 ms
│  ├─ auth-service  verify token                     █                     18 ms
│  ├─ cart-service  load cart                        ███                   74 ms
│  │  └─ redis      GET cart:u#1001                  ▏                      2 ms
│  └─ order-service create order                     ██████████████       690 ms
│     ├─ postgres   INSERT orders                    █                     21 ms
│     └─ payment    POST /charge  (3rd party)        █████████████        655 ms  ◄── the problem
```

- A **trace** is made of **spans**; each span is one unit of work with a
  start, a duration, attributes and a parent.
- Context (the trace ID) is **propagated** between services in request
  headers — the W3C `traceparent` header is the standard.
- **Strengths:** the only pillar that shows *where* time goes across service
  boundaries. Essential for microservices.
- **Weakness:** high volume, so traces are usually **sampled** (keep 1–10%, or
  keep all errors and slow requests with tail-based sampling).

### How the pillars work together

```text
  ALERT fires:   p99 latency on /checkout > 500 ms           ◄── METRICS say THAT
        │
        ▼
  Exemplar on the latency graph links to trace 4bf92f…       ◄── TRACES say WHERE
        │
        ▼
  Span shows payment call took 655 ms; open its logs
  filtered by trace_id=4bf92f…                               ◄── LOGS say WHY
        │
        ▼
  "upstream timeout from payment provider, retry 3/3"
```

The pillars only become observability when they are **correlated** — shared
labels (`service`, `version`, `namespace`, `pod`) and a shared `trace_id`.
Three disconnected tools are three separate monitoring systems.

## Why observability is required

1. **Distributed systems fail in novel ways.** A monolith has one log file and
   one process. Fifty microservices, autoscaling Pods and managed cloud
   services produce failure modes no one predicted, so no one wrote a
   dashboard for them.
2. **Kubernetes is ephemeral.** The Pod that crashed is gone, replaced by one
   with a different name and IP. Without centrally collected telemetry, the
   evidence disappears with it.
3. **Mean time to resolution.** The cost of an outage is mostly the time
   spent *finding* the cause. Correlated telemetry turns hours of guesswork
   into minutes.
4. **SLOs need measurement.** You cannot promise 99.9% availability, or spend
   an error budget, without measuring it accurately.
5. **Deployments need verification.** Canary releases, progressive delivery
   and automated rollbacks all depend on comparing metrics between versions.
6. **Capacity and cost.** Right-sizing requests and limits, tuning HPAs and
   finding waste all start from utilisation data.

## Common tools

| Category | Open source | Commercial / managed |
| --- | --- | --- |
| **Metrics** | Prometheus, Thanos, Mimir, VictoriaMetrics | Datadog, New Relic, CloudWatch, Grafana Cloud |
| **Logs** | Loki, Elasticsearch / OpenSearch (ELK / EFK), Fluent Bit, Fluentd, Vector | Splunk, Datadog Logs, CloudWatch Logs |
| **Traces** | Jaeger, Grafana Tempo, Zipkin | Datadog APM, Honeycomb, AWS X-Ray, Dynatrace |
| **Visualisation** | Grafana, Kibana | Vendor UIs |
| **Alerting** | Alertmanager, Grafana Alerting | PagerDuty, Opsgenie |
| **Instrumentation standard** | **OpenTelemetry** (SDKs + Collector) | — |

**OpenTelemetry** deserves special mention: it is the vendor-neutral CNCF
standard for *producing* all three signals. Instrument once with OTel, and the
**OpenTelemetry Collector** can send the data to any backend — switching
vendors no longer means re-instrumenting code.

A typical open-source stack — often called **LGTM**:

```text
apps (OTel SDK)  ──►  OpenTelemetry Collector
                          │         │          │
                     metrics      logs      traces
                          ▼         ▼          ▼
                     Prometheus   Loki      Tempo
                     / Mimir
                          └─────────┼──────────┘
                                    ▼
                                 Grafana   ──►  Alertmanager ──► Slack / PagerDuty
```

## Kubernetes observability

Kubernetes adds layers that each need observing:

| Layer | What to watch | Source |
| --- | --- | --- |
| **Cluster / control plane** | API server latency and errors, etcd health, scheduler queue | Control-plane `/metrics` endpoints |
| **Nodes** | CPU, memory, disk, network, pressure conditions | **node-exporter** (DaemonSet), kubelet / cAdvisor |
| **Kubernetes objects** | Desired vs available replicas, Pod phase, restarts, pending Pods, HPA state | **kube-state-metrics** |
| **Containers** | CPU and memory usage vs requests and limits, throttling, OOM kills | **cAdvisor** (built into the kubelet) |
| **Applications** | RED metrics, business metrics | The app's own `/metrics` endpoint |
| **Logs** | stdout/stderr of every container | **Fluent Bit / Promtail** DaemonSet tailing `/var/log/containers` |
| **Traces** | Requests across services | OTel SDKs; service meshes (Istio, Linkerd) can emit spans automatically |
| **Events** | Scheduling failures, image pulls, OOM kills, probe failures | `kubectl get events`, or an event exporter |

**Built-in starting points:**

```bash
kubectl top nodes                     # needs metrics-server
kubectl top pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl logs <pod> --previous         # logs of the crashed container
kubectl describe pod <pod>            # status, conditions, recent events
```

`metrics-server` is enough for `kubectl top` and the HPA, but it keeps only
the **current** value — no history, no alerts. For real monitoring, install
the **kube-prometheus-stack** Helm chart, which bundles Prometheus Operator,
Prometheus, Alertmanager, Grafana, node-exporter and kube-state-metrics with
ready-made dashboards and alert rules:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

**Alerts every cluster should have:**

| Alert | Expression idea |
| --- | --- |
| Pod crash looping | `increase(kube_pod_container_status_restarts_total[15m]) > 3` |
| Pod not ready | `kube_pod_status_ready{condition="false"} == 1` for 10m |
| Deployment replicas unavailable | `kube_deployment_status_replicas_unavailable > 0` for 10m |
| Container near memory limit | usage / limit > 0.9 |
| CPU throttling | `rate(container_cpu_cfs_throttled_periods_total[5m])` high |
| Node not ready | `kube_node_status_condition{condition="Ready",status="true"} == 0` |
| PVC almost full | `kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes < 0.1` |
| High error rate | 5xx / total requests > 5% for 5m |

The [monitoring demo](../01-monitoring/) in this session deploys Prometheus,
Grafana, alert rules and an instrumented application on minikube.
