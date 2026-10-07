# Evidence — Final troubleshooting challenge

Executed 2026-10-07 against the platform deployed in [../EVIDENCE.md](../EVIDENCE.md). Output is verbatim;
`<platform-repo>` is the local clone of the GitOps repository. Lines starting with `#` are the operator's notes.

**Note on the diffs:** several `git diff` excerpts of `values-prod.yaml` and `yatri-rules.yml` list every line
of the file as removed and re-added. That is a line-ending change (the files were edited on Windows, CRLF <-> LF),
not a content change — the meaningful change in each is the single line named in the commit message.

## The bad release
```text
# A single commit that looks like a routine release:
79fc385 release 1.1.0: new version, more memory, renamed secret, new hostname, scrape tidy-up
$ git -C "<platform-repo>" show --stat HEAD | tail -4

 helm/yatri-trips/values-prod.yaml |  12 ++-
 monitoring/config/prometheus.yml  | 160 +++++++++++++++++++-------------------
 2 files changed, 88 insertions(+), 84 deletions(-)

$ git -C "<platform-repo>" show HEAD -- helm/yatri-trips/values-prod.yaml monitoring/config/prometheus.yml | grep -E '^[-+] '
-  tag: "1.0.1"
+  tag: "1.1.0"
-  host: yatri-prod.local
+  host: yatri-prod.locl
-    memory: 96Mi
+    memory: 5Gi
-    memory: 256Mi
+    memory: 5Gi
+  create: false
+  existingSecret: yatri-api-key
-  scrape_interval: 15s
-  evaluation_interval: 15s
-  external_labels:
-    cluster: yatri-lab
-  - /etc/prometheus/rules/*.yml
-  alertmanagers:
-    - static_configs:
-        - targets: ["alertmanager.monitoring.svc:9093"]
-  - job_name: prometheus
-    static_configs:
-      - targets: ["localhost:9090"]
-  # Any Pod annotated prometheus.io/scrape: "true" - the Helm chart adds it.
-  - job_name: kubernetes-pods
-    kubernetes_sd_configs:
-      - role: pod
-    relabel_configs:
-      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
-        action: keep
-        regex: "true"
-      - source_labels: [__meta_kubernetes_pod_phase]
-        action: drop
-        regex: (Succeeded|Failed)
-      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
-        target_label: __metrics_path__
-        regex: (.+)
-      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
-        regex: ([^:]+)(?::\d+)?;(\d+)
-        replacement: $1:$2
-        target_label: __address__
-      - source_labels: [__meta_kubernetes_namespace]
-        target_label: namespace
-      - source_labels: [__meta_kubernetes_pod_name]
-        target_label: pod
-      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
-        target_label: app
-      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_version]
-        target_label: version
-  - job_name: kubernetes-cadvisor
-    scheme: https
-    tls_config:
-      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
-    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
-    kubernetes_sd_configs:
-      - role: node
-    relabel_configs:
-      - target_label: __address__
-        replacement: kubernetes.default.svc:443
-      - source_labels: [__meta_kubernetes_node_name]
-        regex: (.+)
-        target_label: __metrics_path__
-        replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
-  # kubelet metrics include kubelet_volume_stats_* (PVC usage).
-  - job_name: kubernetes-kubelet
-    scheme: https
-    tls_config:
-      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
-    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
-    kubernetes_sd_configs:
-      - role: node
-    relabel_configs:
-      - target_label: __address__
-        replacement: kubernetes.default.svc:443
-      - source_labels: [__meta_kubernetes_node_name]
-        regex: (.+)
-        target_label: __metrics_path__
-        replacement: /api/v1/nodes/$1/proxy/metrics
-  - job_name: kube-state-metrics
-    static_configs:
-      - targets: ["kube-state-metrics.monitoring.svc:8080"]
+  scrape_interval: 15s
+  evaluation_interval: 15s
+  external_labels:
+    cluster: yatri-lab
+  - /etc/prometheus/rules/*.yml
+  alertmanagers:
+    - static_configs:
+        - targets: ["alertmanager.monitoring.svc:9093"]
+  - job_name: prometheus
+    static_configs:
+      - targets: ["localhost:9090"]
+  # Any Pod annotated prometheus.io/scrape: "true" - the Helm chart adds it.
+  - job_name: kubernetes-pods
+    kubernetes_sd_configs:
+      - role: pod
+    relabel_configs:
+      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
+        action: keep
+        regex: "true"
+      - source_labels: [__meta_kubernetes_pod_phase]
+        action: drop
+        regex: (Succeeded|Failed)
+      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
+        target_label: __metrics_path__
+        regex: (.+)
+      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
+        regex: ([^:]+)(?::\d+)?;(\d+)
+        replacement: $1:$2
+        target_label: __address__
+      - source_labels: [__meta_kubernetes_namespace]
+        target_label: namespace
+      - source_labels: [__meta_kubernetes_pod_name]
+        target_label: pod
+      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
+        target_label: app
+      - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_version]
+        target_label: version
+  - job_name: kubernetes-cadvisor
+    scheme: https
+    tls_config:
+      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
+    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
+    kubernetes_sd_configs:
+      - role: node
+    relabel_configs:
+      - target_label: __address__
+        replacement: kubernetes.default.svc:443
+      - source_labels: [__meta_kubernetes_node_name]
+        regex: (.+)
+        target_label: __metrics_path__
+        replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
+  # kubelet metrics include kubelet_volume_stats_* (PVC usage).
+  - job_name: kubernetes-kubelet
+    scheme: https
+    tls_config:
+      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
+    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
+    kubernetes_sd_configs:
+      - role: node
+    relabel_configs:
+      - target_label: __address__
+        replacement: kubernetes.default.svc:443
+      - source_labels: [__meta_kubernetes_node_name]
+        regex: (.+)
+        target_label: __metrics_path__
+        replacement: /api/v1/nodes/$1/proxy/metrics
+  - job_name: kube-state-metrics
+    static_configs:
+      - targets: ["kube-state-metric.monitoring.svc:8080"]

```

## Symptom report
```text
# "yatri-prod.local is returning 404 and nobody got paged."
$ curl -H 'Host: yatri-prod.local' http://<ingress>/   -> HTTP 404

yatri-trips: sync=Synced health=Degraded
yatri-monitoring: sync=Synced health=Healthy

```

## Issue 1 - the new version never starts: ResourceQuota
```text
# Identify
$ kubectl -n yatri get deploy yatri-trips
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
yatri-trips   2/2     0            2           4m59s

$ kubectl -n yatri get rs -l app.kubernetes.io/name=yatri-trips
NAME                     DESIRED   CURRENT   READY   AGE
yatri-trips-5dddd95b75   0         0         0       4m59s
yatri-trips-5ffccc9d67   1         0         0       24s
yatri-trips-c8c4f95df    2         2         2       94s

$ kubectl -n yatri get pods -l app.kubernetes.io/name=yatri-trips
NAME                          READY   STATUS    RESTARTS   AGE
yatri-trips-c8c4f95df-9br4m   1/1     Running   0          90s
yatri-trips-c8c4f95df-klwp9   1/1     Running   0          94s

# Investigate - no new Pod exists, so the Pod events are empty; the ReplicaSet has the answer
$ kubectl -n yatri describe rs yatri-trips-5ffccc9d67 | sed -n '/^Events:/,$p' | tail -3
  Warning  FailedCreate  24s               replicaset-controller  Error creating: pods "yatri-trips-5ffccc9d67-q8w7l" is forbidden: exceeded quota: yatri-quota, requested: requests.memory=5Gi, used: requests.memory=192Mi, limited: requests.memory=4Gi
  Warning  FailedCreate  23s               replicaset-controller  Error creating: pods "yatri-trips-5ffccc9d67-d7998" is forbidden: exceeded quota: yatri-quota, requested: requests.memory=5Gi, used: requests.memory=192Mi, limited: requests.memory=4Gi
  Warning  FailedCreate  4s (x4 over 22s)  replicaset-controller  (combined from similar events): Error creating: pods "yatri-trips-5ffccc9d67-sf5xx" is forbidden: exceeded quota: yatri-quota, requested: requests.memory=5Gi, used: requests.memory=192Mi, limited: requests.memory=4Gi

$ kubectl -n yatri describe resourcequota yatri-quota
Name:                   yatri-quota
Namespace:              yatri
Resource                Used   Hard
--------                ----   ----
limits.cpu              1      8
limits.memory           512Mi  8Gi
persistentvolumeclaims  1      5
pods                    2      30
requests.cpu            200m   4
requests.memory         192Mi  4Gi

# Root cause: memory request raised to 5Gi; the namespace quota allows 4Gi of requests in total.
# Fix - in Git
$ git -C "<platform-repo>" diff | grep -E '^[-+] '
-  repository: host.minikube.internal:5000/yatri-trips   # lab registry; ECR URL on AWS
-  tag: "1.1.0"
-  pullPolicy: IfNotPresent
-  APP_ENV: production
-  LOG_LEVEL: info
-  MAX_TRIPS: "5000"
-  host: yatri-prod.locl
-  enabled: true
-  minReplicas: 2
-  maxReplicas: 8
-  targetCPUUtilizationPercentage: 70
-  requests:
-    cpu: 100m
-    memory: 5Gi
-  limits:
-    cpu: 500m
-    memory: 5Gi
-  create: false
-  existingSecret: yatri-api-key
+  repository: host.minikube.internal:5000/yatri-trips   # lab registry; ECR URL on AWS
+  tag: "1.1.0"
+  pullPolicy: IfNotPresent
+  APP_ENV: production
+  LOG_LEVEL: info
+  MAX_TRIPS: "5000"
+  host: yatri-prod.locl
+  enabled: true
+  minReplicas: 2
+  maxReplicas: 8
+  targetCPUUtilizationPercentage: 70
+  requests:
+    cpu: 100m
+    memory: 96Mi
+  limits:
+    cpu: 500m
+    memory: 256Mi
+  create: false
+  existingSecret: yatri-api-key

$ git -C "<platform-repo>" log --oneline -1
1b6d7f8 fix: memory request back within the yatri ResourceQuota

# Verify - Pods are created now ... and the next problem appears
$ kubectl -n yatri get pods -l app.kubernetes.io/name=yatri-trips
NAME                           READY   STATUS             RESTARTS   AGE
yatri-trips-6c8f6b6485-hgwdw   0/1     ImagePullBackOff   0          23s
yatri-trips-c8c4f95df-9br4m    1/1     Running            0          116s
yatri-trips-c8c4f95df-klwp9    1/1     Running            0          2m

```

## Issue 2 - ImagePullBackOff: the image was never published
```text
$ kubectl -n yatri describe pod yatri-trips-6c8f6b6485-hgwdw | sed -n '/^Events:/,$p' | grep -E 'Failed|BackOff' | head -3
  Normal   BackOff    22s                kubelet            spec.containers{api}: Back-off pulling image "host.minikube.internal:5000/yatri-trips:1.1.0"
  Warning  Failed     22s                kubelet            spec.containers{api}: Error: ImagePullBackOff
  Warning  Failed     11s (x2 over 23s)  kubelet            spec.containers{api}: Failed to pull image "host.minikube.internal:5000/yatri-trips:1.1.0": rpc error: code = NotFound desc = failed to pull and unpack image "host.minikube.internal:5000/yatri-trips:1.1.0": failed to resolve reference "host.minikube.internal:5000/yatri-trips:1.1.0": host.minikube.internal:5000/yatri-trips:1.1.0: not found

$ curl -s http://localhost:5000/v2/yatri-trips/tags/list
{"name":"yatri-trips","tags":["1.0.0","1.0.1"]}


# Root cause: values-prod.yaml says 1.1.0 but the pipeline never built 1.1.0 - the tag was bumped by hand.
# Fix - run the release pipeline for 1.1.0 (Git already points at it)
$ bash "<platform-repo>/scripts/pipeline.sh" 1.1.0 "<platform-repo>" 2>&1 | tail -8
SECURITY GATE: PASSED

========== 8/8 Push + GitOps deploy ==========
localhost:5000/yatri-trips:1.1.0
{"name":"yatri-trips","tags":["1.1.0","1.0.0","1.0.1"]}

8fdd45e deploy: yatri-trips 1.1.0
pushed - Argo CD will roll out 1.1.0

$ curl -s http://localhost:5000/v2/yatri-trips/tags/list
{"name":"yatri-trips","tags":["1.1.0","1.0.0","1.0.1"]}


# the kubelet is in pull back-off; delete the Pod so the ReplicaSet retries now
$ kubectl -n yatri delete pod yatri-trips-6c8f6b6485-hgwdw
pod "yatri-trips-6c8f6b6485-hgwdw" deleted from yatri namespace

# Verify - the image pulls ... and the next problem appears
$ kubectl -n yatri get pods -l app.kubernetes.io/name=yatri-trips
NAME                           READY   STATUS                       RESTARTS   AGE
yatri-trips-6c8f6b6485-kn4f2   0/1     CreateContainerConfigError   0          26s
yatri-trips-c8c4f95df-9br4m    1/1     Running                      0          2m49s
yatri-trips-c8c4f95df-klwp9    1/1     Running                      0          2m53s

```

## Issue 3 - CreateContainerConfigError: wrong Secret name
```text
$ kubectl -n yatri describe pod yatri-trips-6c8f6b6485-kn4f2 | sed -n '/^Events:/,$p' | grep -E 'Failed|Error' | head -2
  Warning  Failed     14s (x3 over 25s)  kubelet            spec.containers{api}: Error: secret "yatri-api-key" not found

$ kubectl -n yatri get secrets
NAME                 TYPE     DATA   AGE
yatri-trips-secret   Opaque   1      9m7s

$ git -C "<platform-repo>" log -p -1 79fc385c585b36e81720c0488d14b4601ccd5053 -- helm/yatri-trips/values-prod.yaml | grep -A3 '^+secret'
+secret:
+  create: false
+  existingSecret: yatri-api-key

# Root cause: the release "renamed" the Secret in values only. The real Secret, created by
# Terraform, is still yatri-trips-secret.
# Fix - drop the override in Git
$ git -C "<platform-repo>" diff | grep -E '^[-+] '
-  repository: host.minikube.internal:5000/yatri-trips   # lab registry; ECR URL on AWS
-  tag: "1.1.0"
-  pullPolicy: IfNotPresent
-  APP_ENV: production
-  LOG_LEVEL: info
-  MAX_TRIPS: "5000"
-  host: yatri-prod.locl
-  enabled: true
-  minReplicas: 2
-  maxReplicas: 8
-  targetCPUUtilizationPercentage: 70
-  requests:
-    cpu: 100m
-    memory: 96Mi
-  limits:
-    cpu: 500m
-    memory: 256Mi
-  create: false
-  existingSecret: yatri-api-key
+  repository: host.minikube.internal:5000/yatri-trips   # lab registry; ECR URL on AWS
+  tag: "1.1.0"
+  pullPolicy: IfNotPresent
+  APP_ENV: production
+  LOG_LEVEL: info
+  MAX_TRIPS: "5000"
+  host: yatri-prod.locl
+  enabled: true
+  minReplicas: 2
+  maxReplicas: 8
+  targetCPUUtilizationPercentage: 70
+  requests:
+    cpu: 100m
+    memory: 96Mi
+  limits:
+    cpu: 500m
+    memory: 256Mi

$ kubectl -n yatri rollout status deploy/yatri-trips --timeout=240s
Waiting for deployment "yatri-trips" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "yatri-trips" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "yatri-trips" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "yatri-trips" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "yatri-trips" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "yatri-trips" rollout to finish: 1 old replicas are pending termination...
deployment "yatri-trips" successfully rolled out

# Verify
$ kubectl -n yatri get pods -l app.kubernetes.io/name=yatri-trips -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
POD                            IMAGE                                           READY
yatri-trips-69b9fcc458-wdxzs   host.minikube.internal:5000/yatri-trips:1.1.0   true
yatri-trips-69b9fcc458-wrfdh   host.minikube.internal:5000/yatri-trips:1.1.0   true
yatri-trips-c8c4f95df-klwp9    host.minikube.internal:5000/yatri-trips:1.0.1   false

yatri-trips: sync=Synced health=Progressing

```

## Issue 4 - still 404: the Ingress host
```text
$ curl -H 'Host: yatri-prod.local' http://<ingress>/   -> HTTP 404
$ kubectl -n yatri get ingress
NAME          CLASS   HOSTS             ADDRESS        PORTS   AGE
yatri-trips   nginx   yatri-prod.locl   192.168.49.2   80      6m29s

# Root cause: typo yatri-prod.locl. The controller has no rule for yatri-prod.local -> 404.
# Fix - in Git
$ git -C "<platform-repo>" diff | grep -E '^[-+] '
-  repository: host.minikube.internal:5000/yatri-trips   # lab registry; ECR URL on AWS
-  tag: "1.1.0"
-  pullPolicy: IfNotPresent
-  APP_ENV: production
-  LOG_LEVEL: info
-  MAX_TRIPS: "5000"
-  host: yatri-prod.locl
-  enabled: true
-  minReplicas: 2
-  maxReplicas: 8
-  targetCPUUtilizationPercentage: 70
-  requests:
-    cpu: 100m
-    memory: 96Mi
-  limits:
-    cpu: 500m
-    memory: 256Mi
+  repository: host.minikube.internal:5000/yatri-trips   # lab registry; ECR URL on AWS
+  tag: "1.1.0"
+  pullPolicy: IfNotPresent
+  APP_ENV: production
+  LOG_LEVEL: info
+  MAX_TRIPS: "5000"
+  host: yatri-prod.local
+  enabled: true
+  minReplicas: 2
+  maxReplicas: 8
+  targetCPUUtilizationPercentage: 70
+  requests:
+    cpu: 100m
+    memory: 96Mi
+  limits:
+    cpu: 500m
+    memory: 256Mi

# Verify
$ kubectl -n yatri get ingress
NAME          CLASS   HOSTS              ADDRESS        PORTS   AGE
yatri-trips   nginx   yatri-prod.local   192.168.49.2   80      6m49s

$ curl -H 'Host: yatri-prod.local' http://<ingress>/   -> HTTP 200
$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/
{"service":"yatri-trips","version":"1.1.0","env":"production"}

```

## Issue 5 - why did nobody get paged? Monitoring was half-blind
```text
# Prometheus targets:
  kube-state-metrics   down  Get "http://kube-state-metric.monitoring.svc:8080/metrics": dial tcp: lookup kube-state-metric.
  kubernetes-cadvisor  up    
  kubernetes-kubelet   up    
  kubernetes-pods      up    
  kubernetes-pods      up    
  prometheus           up    

# Active alerts:
  YatriTargetDown          critical pending   Prometheus cannot scrape yatri-trips-6c8f6b6485-kn4f2

# Root cause: the release also "tidied" the scrape config - kube-state-metric (missing s).
# Every alert built on kube-state-metrics (NoReadyReplicas, ImagePullFailing, PodsNotReady,
# CrashLooping) went silent for the whole incident. NOTHING paged: no rule watched Prometheus's
# own targets, and YatriTargetDown was only pending for the one unready Pod. The broken target
# was found by reading the targets list by hand. (Post-incident action: add a meta-alert.)
# Fix - in Git; configMapGenerator gives the ConfigMap a new hash, so Prometheus rolls automatically
$ git -C "<platform-repo>" diff | grep -E '^[-+] '
-      - targets: ["kube-state-metric.monitoring.svc:8080"]
+      - targets: ["kube-state-metrics.monitoring.svc:8080"]

$ kubectl -n monitoring rollout status deploy/prometheus --timeout=180s
Waiting for deployment "prometheus" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "prometheus" rollout to finish: 1 old replicas are pending termination...
deployment "prometheus" successfully rolled out

$ kubectl -n monitoring get deploy prometheus -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}'; echo
prometheus-config-4fb2md2c7g

# Verify
  kube-state-metrics   up    
  kubernetes-cadvisor  up    
  kubernetes-kubelet   up    
  kubernetes-pods      up    
  kubernetes-pods      up    
  prometheus           up    

  (no active alerts)

```

## Final state
```text
yatri-root: sync=Synced health=Healthy
yatri-monitoring: sync=Synced health=Healthy
yatri-trips: sync=Synced health=Healthy

$ kubectl -n yatri get deploy,pods,ingress,hpa,pvc
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-trips   2/2     2            2           8m3s

NAME                               READY   STATUS    RESTARTS   AGE
pod/yatri-trips-69b9fcc458-wdxzs   1/1     Running   0          98s
pod/yatri-trips-69b9fcc458-wrfdh   1/1     Running   0          101s

NAME                                    CLASS   HOSTS              ADDRESS        PORTS   AGE
ingress.networking.k8s.io/yatri-trips   nginx   yatri-prod.local   192.168.49.2   80      8m3s

NAME                                              REFERENCE                TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/yatri-trips   Deployment/yatri-trips   cpu: 1%/70%   2         8         2          8m3s

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/yatri-trips-data   Bound    pvc-adceec3e-b68a-4e89-9f24-dfa8e364e014   256Mi      RWO            standard       <unset>                 8m4s

$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/
{"service":"yatri-trips","version":"1.1.0","env":"production"}

# data written before the incident survived all of it:
$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/api/trips | grep -o '"destination":"[A-Za-z]*"'
"destination":"Jaipur"
"destination":"Leh"
"destination":"Hampi"

# the whole incident, as Git history:
$ git -C "<platform-repo>" log --oneline
eaa1b8d fix: kube-state-metrics scrape target
5d76137 fix: ingress host typo yatri-prod.locl -> yatri-prod.local
1fe51f4 fix: use the Terraform-managed secret yatri-trips-secret
8fdd45e deploy: yatri-trips 1.1.0
1b6d7f8 fix: memory request back within the yatri ResourceQuota
79fc385 release 1.1.0: new version, more memory, renamed secret, new hostname, scrape tidy-up
467828a deploy: yatri-trips 1.0.1
94d2997 deploy: yatri-trips 1.0.0
793f2a9 Yatri platform: app, chart, monitoring, gitops

```

# Post-incident actions

## Post-incident action 1 - alert on the monitoring itself
```text
$ git -C "<platform-repo>" diff --stat
 monitoring/config/yatri-rules.yml | 198 ++++++++++++++++++++------------------
 1 file changed, 105 insertions(+), 93 deletions(-)

$ git -C "<platform-repo>" diff | grep -E '^\+' | grep -v '^+++' | head -14
+groups:
+  # ---------------------------------------------- application (RED + business)
+  - name: yatri-application
+    rules:
+      - alert: YatriTargetDown
+        expr: up{app="yatri-trips"} == 0
+        for: 1m
+        labels: { severity: critical, team: yatri }
+        annotations:
+          summary: "Prometheus cannot scrape {{ $labels.pod }}"
+
+      - alert: YatriNoReadyReplicas
+        expr: kube_deployment_status_replicas_available{namespace="yatri",deployment="yatri-trips"} == 0
+        for: 1m

$ kubectl -n monitoring rollout status deploy/prometheus --timeout=180s
Waiting for deployment "prometheus" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "prometheus" rollout to finish: 1 old replicas are pending termination...
deployment "prometheus" successfully rolled out

$ kubectl -n monitoring exec deploy/prometheus -- promtool check rules /etc/prometheus/rules/yatri.yml
Checking /etc/prometheus/rules/yatri.yml
  SUCCESS: 12 rules found


```

## Post-incident action 2 - game day: break the scrape target on purpose, confirm it pages
```text
$ git -C "<platform-repo>" diff | grep -E '^[-+] '
-      - targets: ["kube-state-metrics.monitoring.svc:8080"]
+      - targets: ["kube-state-metric.monitoring.svc:8080"]

# 164s after Prometheus restarted with the broken config:
$ curl prometheus:9090/api/v1/alerts   (summarised)
  MonitoringTargetDown   critical firing    Prometheus cannot scrape job kube-state-metrics (kube-state-metric.monitoring.svc:8080) - alerts tha

$ curl alertmanager:9093/api/v2/alerts   (summarised)
  MonitoringTargetDown   active   receivers=['alert-log']

$ kubectl -n monitoring logs deploy/alert-log --tail=20 | grep -o '"status":"[a-z]*","labels":{"alertname":"MonitoringTargetDown"[^}]*' | tail -2
"status":"firing","labels":{"alertname":"MonitoringTargetDown","cluster":"yatri-lab","instance":"kube-state-metric.monitoring.svc:8080","job":"kube-state-metrics","severity":"critical","team":"platform"

```

## Post-incident action 3 - revert the game-day break
```text
$ git -C "<platform-repo>" log --oneline -3
e9a7d85 Revert "game day: break the kube-state-metrics scrape target"
fe5a5af game day: break the kube-state-metrics scrape target
a980d81 post-incident: alert when any scrape target is down (MonitoringTargetDown)

$ kubectl -n monitoring rollout status deploy/prometheus --timeout=180s
deployment "prometheus" successfully rolled out

$ curl prometheus:9090/api/v1/targets   (summarised)
  kube-state-metrics   up
  kubernetes-cadvisor  up
  kubernetes-kubelet   up
  kubernetes-pods      up
  kubernetes-pods      up
  prometheus           up

$ curl prometheus:9090/api/v1/alerts   (summarised)
  (no active alerts)

yatri-root: sync=Synced health=Healthy
yatri-monitoring: sync=Synced health=Healthy
yatri-trips: sync=Synced health=Healthy
$ git -C "<platform-repo>" log --oneline
e9a7d85 Revert "game day: break the kube-state-metrics scrape target"
fe5a5af game day: break the kube-state-metrics scrape target
a980d81 post-incident: alert when any scrape target is down (MonitoringTargetDown)
eaa1b8d fix: kube-state-metrics scrape target
5d76137 fix: ingress host typo yatri-prod.locl -> yatri-prod.local
1fe51f4 fix: use the Terraform-managed secret yatri-trips-secret
8fdd45e deploy: yatri-trips 1.1.0
1b6d7f8 fix: memory request back within the yatri ResourceQuota
79fc385 release 1.1.0: new version, more memory, renamed secret, new hostname, scrape tidy-up
467828a deploy: yatri-trips 1.0.1
94d2997 deploy: yatri-trips 1.0.0
793f2a9 Yatri platform: app, chart, monitoring, gitops

```
