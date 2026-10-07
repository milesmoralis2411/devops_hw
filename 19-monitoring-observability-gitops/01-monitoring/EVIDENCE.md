# Evidence — Monitoring demo

Executed on minikube v1.39.0 / Kubernetes v1.37.0 with Prometheus v2.55.1, Alertmanager v0.27.0, Grafana 11.3.0, kube-state-metrics v2.13.0, 2026-10-07. Output is verbatim.

## 1. Deploy the monitoring stack
```text
$ kubectl apply -f k8s/00-namespace.yaml
namespace/monitoring created

$ kubectl -n monitoring create secret generic grafana-admin --from-literal=password=<generated>
secret/grafana-admin created

$ kubectl apply -f k8s/
namespace/monitoring unchanged
deployment.apps/metrics-app created
service/metrics-app created
serviceaccount/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
configmap/prometheus-config created
configmap/prometheus-rules created
deployment.apps/prometheus created
service/prometheus created
serviceaccount/kube-state-metrics created
clusterrole.rbac.authorization.k8s.io/kube-state-metrics created
clusterrolebinding.rbac.authorization.k8s.io/kube-state-metrics created
deployment.apps/kube-state-metrics created
service/kube-state-metrics created
configmap/alertmanager-config created
deployment.apps/alertmanager created
service/alertmanager created
deployment.apps/alert-webhook created
service/alert-webhook created
configmap/grafana-datasources created
configmap/grafana-dashboard-provider created
configmap/grafana-dashboards created
deployment.apps/grafana created
service/grafana created

$ kubectl -n monitoring get deploy,pods,svc
NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/alert-webhook        1/1     1            1           2m3s
deployment.apps/alertmanager         1/1     1            1           2m3s
deployment.apps/grafana              1/1     1            1           2m2s
deployment.apps/kube-state-metrics   1/1     1            1           2m3s
deployment.apps/metrics-app          2/2     2            2           2m4s
deployment.apps/prometheus           1/1     1            1           2m3s

NAME                                      READY   STATUS    RESTARTS   AGE
pod/alert-webhook-647f5bc76-szvcs         1/1     Running   0          2m3s
pod/alertmanager-6447574b65-c2gjg         1/1     Running   0          2m3s
pod/grafana-8677ccdc76-w6mfl              1/1     Running   0          2m1s
pod/kube-state-metrics-6fff977768-nx6jb   1/1     Running   0          2m3s
pod/metrics-app-78b99f4468-2ws7t          1/1     Running   0          2m3s
pod/metrics-app-78b99f4468-fkhb2          1/1     Running   0          2m3s
pod/prometheus-6b5b8798b7-6twhn           1/1     Running   0          2m3s

NAME                         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/alert-webhook        ClusterIP   10.96.242.234    <none>        8080/TCP         2m2s
service/alertmanager         NodePort    10.100.159.215   <none>        9093:30093/TCP   2m3s
service/grafana              NodePort    10.110.101.211   <none>        3000:30300/TCP   2m1s
service/kube-state-metrics   ClusterIP   10.106.99.56     <none>        8080/TCP         2m3s
service/metrics-app          ClusterIP   10.106.216.81    <none>        80/TCP           2m3s
service/prometheus           NodePort    10.110.195.152   <none>        9090:30090/TCP   2m3s

```

## 2. Prometheus discovered its targets
```text
$ curl prometheus:9090/api/v1/targets   (summarised)
  kube-state-metrics     up     http://kube-state-metrics.monitoring.svc:8080/metrics
  kubernetes-cadvisor    up     https://kubernetes.default.svc:443/api/v1/nodes/minikube/proxy/metrics/cadvisor
  kubernetes-pods        up     http://10.244.0.57:8080/metrics
  kubernetes-pods        up     http://10.244.0.54:8080/metrics
  prometheus             up     http://localhost:9090/metrics

```

## 3. Generate traffic: normal requests, CPU work and some errors
```text
pod/traffic created
# ~10% of requests hit /error, so the 5% error-rate alert should fire
```

## 4. Metrics - request rate, errors, latency
```text
$ promql: sum by (route, status) (rate(http_requests_total{app="metrics-app"}[1m]))
  route=/readyz,status=200                                     0.4
  route=/healthz,status=200                                    0.1778
  route=/,status=200                                           18.3564
  route=/work,status=200                                       2.2668
  route=/error,status=500                                      2.3112

$ promql: sum(rate(http_requests_total{app="metrics-app",status=~"5.."}[1m])) / sum(rate(http_requests_total{app="metrics-app"}[1m]))
  {}                                                           0.0983

$ promql: histogram_quantile(0.95, sum by (le, route) (rate(http_request_duration_seconds_bucket{app="metrics-app"}[2m])))
  route=/healthz                                               0.0047
  route=/                                                      0.0048
  route=/work                                                  0.2425
  route=/error                                                 0.0047
  route=/readyz                                                0.0047

```

## 5. CPU utilisation and memory utilisation
```text
$ promql: sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="monitoring",pod=~"metrics-app.*",container!=""}[1m]))
  pod=metrics-app-78b99f4468-2ws7t                             0.1537
  pod=metrics-app-78b99f4468-fkhb2                             0.1459

$ promql: sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="monitoring",pod=~"metrics-app.*",container!=""}[1m])) / sum by (pod) (kube_pod_container_resource_limits{namespace="monitoring",pod=~"metrics-app.*",resource="cpu"})
  pod=metrics-app-78b99f4468-2ws7t                             0.3073
  pod=metrics-app-78b99f4468-fkhb2                             0.2918

$ promql: sum by (pod) (container_memory_working_set_bytes{namespace="monitoring",pod=~"metrics-app.*",container!=""})
  pod=metrics-app-78b99f4468-2ws7t                             15069184.0
  pod=metrics-app-78b99f4468-fkhb2                             18837504.0

$ promql: sum by (pod) (container_memory_working_set_bytes{namespace="monitoring",pod=~"metrics-app.*",container!=""}) / sum by (pod) (kube_pod_container_resource_limits{namespace="monitoring",pod=~"metrics-app.*",resource="memory"})
  pod=metrics-app-78b99f4468-2ws7t                             0.1123
  pod=metrics-app-78b99f4468-fkhb2                             0.1404

$ kubectl top pods -n monitoring
NAME                                  CPU(cores)   MEMORY(bytes)   
alert-webhook-647f5bc76-szvcs         1m           9Mi             
alertmanager-6447574b65-c2gjg         2m           14Mi            
grafana-8677ccdc76-w6mfl              7m           61Mi            
kube-state-metrics-6fff977768-nx6jb   2m           13Mi            
metrics-app-78b99f4468-2ws7t          160m         13Mi            
metrics-app-78b99f4468-fkhb2          143m         17Mi            
prometheus-6b5b8798b7-6twhn           5m           91Mi            
traffic                               45m          3Mi             

```

## 6. Logs - structured JSON from the application
```text
$ kubectl -n monitoring logs deploy/metrics-app --tail=6
Found 2 pods, using pod/metrics-app-78b99f4468-2ws7t
{"ts":"2026-10-07T16:40:12.737Z","level":"info","method":"GET","route":"/","status":200,"duration_ms":0,"version":"1.0.0"}
{"ts":"2026-10-07T16:40:12.939Z","level":"info","method":"GET","route":"/work","status":200,"duration_ms":200,"version":"1.0.0"}
{"ts":"2026-10-07T16:40:12.941Z","level":"error","method":"GET","route":"/error","status":500,"duration_ms":0,"version":"1.0.0"}
{"ts":"2026-10-07T16:40:13.149Z","level":"info","method":"GET","route":"/","status":200,"duration_ms":0,"version":"1.0.0"}
{"ts":"2026-10-07T16:40:13.359Z","level":"info","method":"GET","route":"/work","status":200,"duration_ms":200,"version":"1.0.0"}
{"ts":"2026-10-07T16:40:13.361Z","level":"error","method":"GET","route":"/error","status":500,"duration_ms":0,"version":"1.0.0"}

# because they are JSON, they can be filtered like data:
$ kubectl -n monitoring logs -l app=metrics-app --tail=500 | grep '"level":"error"' | tail -2
{"ts":"2026-10-07T16:40:12.076Z","level":"error","method":"GET","route":"/error","status":500,"duration_ms":0,"version":"1.0.0"}
{"ts":"2026-10-07T16:40:12.521Z","level":"error","method":"GET","route":"/error","status":500,"duration_ms":0,"version":"1.0.0"}

```

## 7. Alerts - fired by Prometheus, routed by Alertmanager
```text
$ curl prometheus:9090/api/v1/alerts   (summarised)
  HighErrorRate      warning  firing    More than 5% of metrics-app requests are failing

$ curl alertmanager:9093/api/v2/alerts   (summarised)
  HighErrorRate      active   receivers=['webhook-logger']

$ kubectl -n monitoring logs deploy/alert-webhook | tail -5
alert webhook listening on 8080
[FIRING] HighErrorRate severity=warning pod=- :: More than 5% of metrics-app requests are failing

```

## 8. Application health - one Pod reports itself not ready
```text
$ kubectl -n monitoring exec metrics-app-78b99f4468-2ws7t -- wget -qO- http://127.0.0.1:8080/toggle-ready
{"ready":false}
$ kubectl -n monitoring get pods -l app=metrics-app
NAME                           READY   STATUS    RESTARTS   AGE
metrics-app-78b99f4468-2ws7t   0/1     Running   0          5m52s
metrics-app-78b99f4468-fkhb2   1/1     Running   0          5m52s

$ promql: kube_deployment_status_replicas_available{deployment="metrics-app"}
  deployment=metrics-app                                       1.0

$ promql: app_ready{app="metrics-app"}
  app=metrics-app,pod=metrics-app-78b99f4468-2ws7t             0.0
  app=metrics-app,pod=metrics-app-78b99f4468-fkhb2             1.0

$ promql: up{app="metrics-app"}
  app=metrics-app,pod=metrics-app-78b99f4468-2ws7t             1.0
  app=metrics-app,pod=metrics-app-78b99f4468-fkhb2             1.0

$ curl prometheus:9090/api/v1/alerts   (summarised)
  HighErrorRate      firing    More than 5% of metrics-app requests are failing
  AppNotReady        firing    Pod metrics-app-78b99f4468-2ws7t reports itself not ready
  DeploymentReplicasUnavailable pending   monitoring/metrics-app has unavailable replicas
  DeploymentReplicasUnavailable pending   gitea/gitea has unavailable replicas

# recover the Pod; the alert resolves and Alertmanager sends a RESOLVED notification
$ kubectl -n monitoring exec metrics-app-78b99f4468-2ws7t -- wget -qO- http://127.0.0.1:8080/toggle-ready
{"ready":true}
```

## 9. Grafana - datasource and dashboard provisioned from ConfigMaps
```text
$ kubectl -n monitoring exec deploy/grafana -- wget -qO- http://localhost:3000/api/health
{
  "database": "ok",
  "version": "11.3.0",
  "commit": "d9455ff7db73b694db7d412e49a68bec767f2b5a"
}
$ curl -u admin:*** grafana:3000/api/datasources/uid/prometheus/health
{"details":{"application":"Prometheus","features":{"rulerApiEnabled":false}},"message":"Successfully queried the Prometheus API.","status":"OK"}

$ curl grafana:3000/api/search?query=metrics-app
  title=metrics-app - Service Health  folder=Homework  uid=metrics-app  url=/d/metrics-app/metrics-app-service-health

$ curl grafana:3000/api/dashboards/uid/metrics-app   (panel titles)
  [stat] Ready replicas
  [stat] Targets up
  [stat] Error ratio (1m)
  [stat] Container restarts
  [timeseries] Request rate by route and status
  [timeseries] Latency p50 / p95
  [timeseries] CPU utilisation per Pod (cores)
  [timeseries] Memory working set per Pod

# open it: kubectl -n monitoring port-forward svc/grafana 3000:3000  ->  http://localhost:3000/d/metrics-app
```

## 10. Notifications received 60s after recovery (RESOLVED not yet sent)
```text
$ kubectl -n monitoring logs deploy/alert-webhook | grep -E 'FIRING|RESOLVED' | sort -u | tail -8
[FIRING] AppNotReady severity=warning pod=metrics-app-78b99f4468-2ws7t :: Pod metrics-app-78b99f4468-2ws7t reports itself not ready
[FIRING] DeploymentReplicasUnavailable severity=warning pod=- :: monitoring/metrics-app has unavailable replicas
[FIRING] HighErrorRate severity=warning pod=- :: More than 5% of metrics-app requests are failing

```

## 11. A few minutes later - Alertmanager sent the RESOLVED notifications

```text
$ kubectl -n monitoring logs deploy/alert-webhook | grep -E "FIRING|RESOLVED" | sort | uniq -c
      1 [FIRING] AppNotReady severity=warning pod=metrics-app-78b99f4468-2ws7t :: Pod metrics-app-78b99f4468-2ws7t reports itself not ready
      1 [FIRING] DeploymentReplicasUnavailable severity=warning pod=- :: monitoring/metrics-app has unavailable replicas
      1 [FIRING] HighErrorRate severity=warning pod=- :: More than 5% of metrics-app requests are failing
      1 [RESOLVED] AppNotReady severity=warning pod=metrics-app-78b99f4468-2ws7t :: Pod metrics-app-78b99f4468-2ws7t reports itself not ready
      1 [RESOLVED] DeploymentReplicasUnavailable severity=warning pod=- :: monitoring/metrics-app has unavailable replicas
      1 [RESOLVED] HighErrorRate severity=warning pod=- :: More than 5% of metrics-app requests are failing
```
