# Evidence — Final project, end-to-end deployment

Executed 2026-10-07 on Windows 11 + Docker Desktop: minikube v1.39.0 (Kubernetes v1.37.0, containerd),
Terraform v1.16.5, Argo CD v3.5.4 (Helm chart 10.10.0), Gitea 1.27.3, registry:2,
Trivy 0.57.1, Gitleaks 8.21.2, Semgrep 1.179.0. Output is verbatim; `<platform-repo>` stands for the
local clone of the GitOps repository (a temporary directory). The incident run is in
[troubleshooting/EVIDENCE.md](troubleshooting/EVIDENCE.md).

## 0. Lab prerequisites: a container registry the cluster can pull from
```text
$ docker run -d --name yatri-registry -p 5000:5000 --restart unless-stopped registry:2
7a0a63ed236602ae8a8e36f8d23095221323d7bbee269b798e7baab5c2ccf51c

# minikube containerd: allow plain-HTTP pulls from the host registry
$ minikube ssh -- cat /etc/containerd/certs.d/host.minikube.internal:5000/hosts.toml
[host."http://host.minikube.internal:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true

```

## 1. Terraform - bootstrap the cluster (namespaces, guardrails, secrets, Argo CD)
```text
$ terraform init
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/kubernetes from the dependency lock file
- Reusing previous version of hashicorp/helm from the dependency lock file
- Reusing previous version of hashicorp/random from the dependency lock file
- Using previously-installed hashicorp/random v3.9.1
- Using previously-installed hashicorp/kubernetes v2.38.0
- Using previously-installed hashicorp/helm v2.17.0

Terraform has been successfully initialized!

$ terraform fmt -check

$ terraform validate
Success! The configuration is valid.


$ terraform plan -out=bootstrap.tfplan

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # helm_release.argocd will be created
  + resource "helm_release" "argocd" {
      + atomic                     = false
      + chart                      = "argo-cd"
      + cleanup_on_fail            = false
      + create_namespace           = false
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + manifest                   = (known after apply)
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "argocd"
      + namespace                  = "argocd"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + repository                 = "https://argoproj.github.io/argo-helm"
      + reset_values               = false
      + reuse_values               = false
      + skip_crds                  = false
      + status                     = "deployed"
      + timeout                    = 900
      + values                     = [
          + <<-EOT
                "configs":
                  "cm":
                    "timeout.reconciliation": "30s"
                  "params":
                    "server.insecure": true
                "dex":
                  "enabled": false
            EOT,
        ]
      + verify                     = false
      + version                    = "10.10.0"
      + wait                       = true
      + wait_for_jobs              = false
    }

  # kubernetes_limit_range.app will be created
  + resource "kubernetes_limit_range" "app" {
      + id = (known after apply)

      + metadata {
          + generation       = (known after apply)
          + name             = "yatri-defaults"
          + namespace        = "yatri"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }

      + spec {
          + limit {
              + default         = {
                  + "cpu"    = "300m"
                  + "memory" = "256Mi"
                }
              + default_request = {
                  + "cpu"    = "50m"
                  + "memory" = "64Mi"
                }
              + type            = "Container"
            }
        }
    }

  # kubernetes_namespace.app will be created
  + resource "kubernetes_namespace" "app" {
      + id                               = (known after apply)
      + wait_for_default_service_account = false

      + metadata {
          + generation       = (known after apply)
          + labels           = {
              + "app.kubernetes.io/part-of"          = "yatri"
              + "pod-security.kubernetes.io/enforce" = "restricted"
              + "pod-security.kubernetes.io/warn"    = "restricted"
            }
          + name             = "yatri"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # kubernetes_namespace.argocd will be created
  + resource "kubernetes_namespace" "argocd" {
      + id                               = (known after apply)
      + wait_for_default_service_account = false

      + metadata {
          + generation       = (known after apply)
          + labels           = {
              + "app.kubernetes.io/part-of" = "yatri"
            }
          + name             = "argocd"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # kubernetes_namespace.monitoring will be created
  + resource "kubernetes_namespace" "monitoring" {
      + id                               = (known after apply)
      + wait_for_default_service_account = false

      + metadata {
          + generation       = (known after apply)
          + labels           = {
              + "app.kubernetes.io/part-of" = "yatri"
            }
          + name             = "monitoring"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # kubernetes_resource_quota.app will be created
  + resource "kubernetes_resource_quota" "app" {
      + id = (known after apply)

      + metadata {
          + generation       = (known after apply)
          + name             = "yatri-quota"
          + namespace        = "yatri"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }

      + spec {
          + hard = {
              + "limits.cpu"             = "8"
              + "limits.memory"          = "8Gi"
              + "persistentvolumeclaims" = "5"
              + "pods"                   = "30"
              + "requests.cpu"           = "4"
              + "requests.memory"        = "4Gi"
            }
        }
    }

  # kubernetes_secret.api_key will be created
  + resource "kubernetes_secret" "api_key" {
      + binary_data_wo                 = (write-only attribute)
      + data                           = (sensitive value)
      + data_wo                        = (write-only attribute)
      + id                             = (known after apply)
      + type                           = "Opaque"
      + wait_for_service_account_token = true

      + metadata {
          + generation       = (known after apply)
          + labels           = {
              + "app.kubernetes.io/part-of" = "yatri"
            }
          + name             = "yatri-trips-secret"
          + namespace        = "yatri"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # kubernetes_secret.grafana_admin will be created
  + resource "kubernetes_secret" "grafana_admin" {
      + binary_data_wo                 = (write-only attribute)
      + data                           = (sensitive value)
      + data_wo                        = (write-only attribute)
      + id                             = (known after apply)
      + type                           = "Opaque"
      + wait_for_service_account_token = true

      + metadata {
          + generation       = (known after apply)
          + name             = "grafana-admin"
          + namespace        = "monitoring"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # random_password.api_key will be created
  + resource "random_password" "api_key" {
      + bcrypt_hash = (sensitive value)
      + id          = (known after apply)
      + length      = 40
      + lower       = true
      + min_lower   = 0
      + min_numeric = 0
      + min_special = 0
      + min_upper   = 0
      + number      = true
      + numeric     = true
      + result      = (sensitive value)
      + special     = false
      + upper       = true
    }

  # random_password.grafana will be created
  + resource "random_password" "grafana" {
      + bcrypt_hash = (sensitive value)
      + id          = (known after apply)
      + length      = 24
      + lower       = true
      + min_lower   = 0
      + min_numeric = 0
      + min_special = 0
      + min_upper   = 0
      + number      = true
      + numeric     = true
      + result      = (sensitive value)
      + special     = false
      + upper       = true
    }

Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + api_key                       = (sensitive value)
  + api_key_secret                = "yatri/yatri-trips-secret"
  + argocd_admin_password_command = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  + argocd_version                = (known after apply)
  + grafana_admin_password        = (sensitive value)
  + namespaces                    = [
      + "yatri",
      + "monitoring",
      + "argocd",
    ]

$ terraform apply bootstrap.tfplan
random_password.api_key: Creating...
random_password.grafana: Creating...
kubernetes_namespace.argocd: Creating...
kubernetes_namespace.monitoring: Creating...
kubernetes_namespace.app: Creating...
kubernetes_namespace.monitoring: Creation complete after 0s [id=monitoring]
kubernetes_namespace.app: Creation complete after 0s [id=yatri]
kubernetes_namespace.argocd: Creation complete after 0s [id=argocd]
kubernetes_resource_quota.app: Creating...
kubernetes_limit_range.app: Creating...
kubernetes_limit_range.app: Creation complete after 0s [id=yatri/yatri-defaults]
random_password.api_key: Creation complete after 0s [id=none]
random_password.grafana: Creation complete after 0s [id=none]
kubernetes_secret.grafana_admin: Creating...
kubernetes_secret.api_key: Creating...
kubernetes_secret.grafana_admin: Creation complete after 0s [id=monitoring/grafana-admin]
kubernetes_secret.api_key: Creation complete after 0s [id=yatri/yatri-trips-secret]
kubernetes_resource_quota.app: Creation complete after 1s [id=yatri/yatri-quota]
helm_release.argocd: Creating...
helm_release.argocd: Still creating... [00m10s elapsed]
helm_release.argocd: Still creating... [00m20s elapsed]
helm_release.argocd: Still creating... [00m30s elapsed]
helm_release.argocd: Still creating... [00m40s elapsed]
helm_release.argocd: Still creating... [00m50s elapsed]
helm_release.argocd: Still creating... [01m00s elapsed]
helm_release.argocd: Still creating... [01m10s elapsed]
helm_release.argocd: Still creating... [01m20s elapsed]
helm_release.argocd: Still creating... [01m30s elapsed]
helm_release.argocd: Still creating... [01m40s elapsed]
helm_release.argocd: Still creating... [01m50s elapsed]
helm_release.argocd: Creation complete after 1m57s [id=argocd]

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

api_key = <sensitive>
api_key_secret = "yatri/yatri-trips-secret"
argocd_admin_password_command = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
argocd_version = "argo-cd 10.10.0 (app v3.5.4)"
grafana_admin_password = <sensitive>
namespaces = [
  "yatri",
  "monitoring",
  "argocd",
]

$ terraform output
api_key = <sensitive>
api_key_secret = "yatri/yatri-trips-secret"
argocd_admin_password_command = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
argocd_version = "argo-cd 10.10.0 (app v3.5.4)"
grafana_admin_password = <sensitive>
namespaces = [
  "yatri",
  "monitoring",
  "argocd",
]

$ kubectl get ns yatri monitoring argocd --show-labels
NAME         STATUS   AGE   LABELS
yatri        Active   2m    app.kubernetes.io/part-of=yatri,kubernetes.io/metadata.name=yatri,pod-security.kubernetes.io/enforce=restricted,pod-security.kubernetes.io/warn=restricted
monitoring   Active   2m    app.kubernetes.io/part-of=yatri,kubernetes.io/metadata.name=monitoring
argocd       Active   2m    app.kubernetes.io/part-of=yatri,kubernetes.io/metadata.name=argocd

$ kubectl -n yatri get resourcequota,limitrange,secret
NAME                        REQUEST                                                                              LIMIT                                   AGE
resourcequota/yatri-quota   persistentvolumeclaims: 0/5, pods: 0/30, requests.cpu: 0/4, requests.memory: 0/4Gi   limits.cpu: 0/8, limits.memory: 0/8Gi   2m

NAME                        CREATED AT
limitrange/yatri-defaults   2026-10-07T17:18:07Z

NAME                        TYPE     DATA   AGE
secret/yatri-trips-secret   Opaque   1      2m

$ kubectl -n argocd get pods
NAME                                               READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                    1/1     Running   0          105s
argocd-applicationset-controller-5c9d6d98c-8plvn   1/1     Running   0          106s
argocd-notifications-controller-7747455f86-dnvfw   1/1     Running   0          106s
argocd-redis-757969f6f8-gk6w2                      1/1     Running   0          106s
argocd-repo-server-5f69f4f55c-fd9rh                1/1     Running   0          105s
argocd-server-cc7c4d859-4w9lw                      1/1     Running   0          105s

$ terraform output -raw api_key     # (kept in a shell variable, not printed)
api key length: 40
```

## 2. Git server + the platform repository
```text
$ kubectl apply -f gitops/git-server/gitea.yaml
namespace/gitea created
deployment.apps/gitea created
service/gitea created

$ kubectl -n gitea rollout status deploy/gitea --timeout=600s
Waiting for deployment "gitea" rollout to finish: 0 of 1 updated replicas are available...
deployment "gitea" successfully rolled out

created Gitea user 'yatri' (password generated, not shown)
$ git push http://yatri:****@localhost:3300/yatri/platform.git main
$ git -C "<platform-repo>" log --oneline
793f2a9 Yatri platform: app, chart, monitoring, gitops

$ git -C "<platform-repo>" ls-files | cut -d/ -f1 | sort | uniq -c
      1 .github
     10 application
      3 docker
      5 gitops
     14 helm
     10 kubernetes
      8 monitoring
      1 scripts
      5 security
     13 terraform
      2 troubleshooting

```

## 3. CI pipeline - build, scan, gate and publish v1.0.0
```text
$ bash "<platform-repo>/scripts/pipeline.sh" 1.0.0 "<platform-repo>"

========== 1/8 Unit tests ==========
✔ validateTrip accepts a valid trip (2.1561ms)
✔ validateTrip rejects bad input (0.2142ms)
✔ store persists trips to disk and reloads them (7.0348ms)
✔ concurrent writers from separate processes lose no trips (411.2384ms)
✔ GET / returns service info (12.7316ms)
✔ GET /healthz and /readyz report healthy (2.7286ms)
✔ POST /api/trips requires the API key (2.3375ms)
✔ POST, GET and DELETE a trip (13.3932ms)
✔ POST rejects invalid payloads (1.2689ms)
✔ trip limit is enforced (11.6547ms)
✔ GET /metrics exposes Prometheus metrics (2.5336ms)
✔ unknown routes return 404 (1.0085ms)
ℹ tests 12
ℹ pass 12
ℹ fail 0

========== 2/8 SAST ==========
semgrep not installed locally - SAST runs in the GitHub Actions job (semgrep/semgrep container)

========== 3/8 SCA + IaC scanning - dependencies and misconfigurations ==========
found 0 vulnerabilities
trivy fs: no HIGH/CRITICAL vulnerabilities, misconfigurations or secrets (1 accepted risk in .trivyignore)

========== 4/8 Secret scanning ==========
[90m5:20PM[0m [32mINF[0m scan completed in 694ms
[90m5:20PM[0m [32mINF[0m no leaks found
gitleaks: no secrets found

========== 5/8 Build image yatri-trips:1.0.0 ==========
sha256:725aa7db9bccd700d5f67c18784f05a26135aaf7c14dff65407a32f576e17932
size=60716582 user=node created=2026-10-07T17:17:41.262716869Z

========== 6/8 Image scan ==========
yatri-trips:1.0.0 (alpine 3.24.2): 0 HIGH/CRITICAL
Node.js: 0 HIGH/CRITICAL

========== 7/8 Security gate ==========
Policy : CRITICAL <= 0, HIGH <= 5 (fixable only)
Found  : CRITICAL = 0, HIGH = 0
SECURITY GATE: PASSED

========== 8/8 Push + GitOps deploy ==========
localhost:5000/yatri-trips:1.0.0
{"name":"yatri-trips","tags":["1.0.0"]}

94d2997 deploy: yatri-trips 1.0.0
pushed - Argo CD will roll out 1.0.0

$ curl -s http://localhost:5000/v2/_catalog
{"repositories":["yatri-trips"]}

```

## 4. GitOps - one Application by hand, everything else from Git
```text
$ cat gitops/root-app.yaml
# App of Apps: the only object applied by hand. It points Argo CD at gitops/apps/,
# and every Application in that folder is created and managed from Git.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: yatri-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.gitea.svc.cluster.local:3000/yatri/platform.git
    targetRevision: main
    path: gitops/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

$ kubectl apply -f gitops/root-app.yaml
application.argoproj.io/yatri-root created

$ kubectl -n argocd get applications
NAME               SYNC STATUS   HEALTH STATUS
yatri-monitoring   Synced        Healthy
yatri-root         Synced        Healthy
yatri-trips        Synced        Healthy

yatri-root: sync=Synced health=Healthy rev=94d2997c9d233592cd61dcc28b4202c0ced402f1
yatri-monitoring: sync=Synced health=Healthy rev=94d2997c9d233592cd61dcc28b4202c0ced402f1
yatri-trips: sync=Synced health=Healthy rev=94d2997c9d233592cd61dcc28b4202c0ced402f1

```

## 5. Verify the deployment
```text
$ kubectl -n yatri get deploy,rs,pods,svc,ingress,hpa,pdb,pvc
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-trips   2/2     2            2           2m6s

NAME                                     DESIRED   CURRENT   READY   AGE
replicaset.apps/yatri-trips-5dddd95b75   2         2         2       2m6s

NAME                               READY   STATUS    RESTARTS   AGE
pod/yatri-trips-5dddd95b75-457ph   1/1     Running   0          2m6s
pod/yatri-trips-5dddd95b75-krq2g   1/1     Running   0          2m6s

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/yatri-trips   ClusterIP   10.102.158.75   <none>        80/TCP    2m7s

NAME                                    CLASS   HOSTS              ADDRESS        PORTS   AGE
ingress.networking.k8s.io/yatri-trips   nginx   yatri-prod.local   192.168.49.2   80      2m6s

NAME                                              REFERENCE                TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/yatri-trips   Deployment/yatri-trips   cpu: 2%/70%   2         8         2          2m6s

NAME                                     MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/yatri-trips   1               N/A               1                     2m8s

NAME                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/yatri-trips-data   Bound    pvc-adceec3e-b68a-4e89-9f24-dfa8e364e014   256Mi      RWO            standard       <unset>                 2m7s

$ kubectl -n yatri get pod -l app.kubernetes.io/name=yatri-trips -o jsonpath='{range .items[*]}{.metadata.name}  image={.spec.containers[0].image}  user={.spec.securityContext.runAsUser}{"\n"}{end}'
yatri-trips-5dddd95b75-457ph  image=host.minikube.internal:5000/yatri-trips:1.0.0  user=1000
yatri-trips-5dddd95b75-krq2g  image=host.minikube.internal:5000/yatri-trips:1.0.0  user=1000

$ kubectl -n yatri describe pod -l app.kubernetes.io/name=yatri-trips | grep -E '^\s+(Liveness|Readiness|Startup):' | head -3
    Liveness:   http-get http://:http/healthz delay=0s timeout=1s period=10s #success=1 #failure=3
    Readiness:  http-get http://:http/readyz delay=0s timeout=1s period=5s #success=1 #failure=3
    Startup:    http-get http://:http/healthz delay=0s timeout=1s period=2s #success=1 #failure=30

# through the Ingress
$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/
{"service":"yatri-trips","version":"1.0.0","env":"production"}
$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/readyz
{"status":"ready","storage":true,"apiKeyConfigured":true}
# write requires the API key from the Terraform-managed Secret
$ minikube ssh -- "curl -s -w ' [HTTP_%{http_code}]' -X POST -H 'Host:yatri-prod.local' http://localhost/api/trips"
{"error":"missing or invalid x-api-key"} [HTTP_401]
$ minikube ssh -- "curl -s -w ' [HTTP_%{http_code}]' -X POST -H 'Host:yatri-prod.local' -H 'x-api-key: wrong-key' http://localhost/api/trips"
{"error":"missing or invalid x-api-key"} [HTTP_401]


$ curl -X POST -H "x-api-key: ****" ... /api/trips   # x3: Jaipur, Leh, Hampi
$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/api/trips
[{"id":"e5c55af7-ca68-4443-b032-1086dc648913","destination":"Jaipur","days":3,"createdAt":"2026-10-07T17:23:04.176Z"},{"id":"f72b8b24-ebf0-4697-aba7-8ff7271f669f","destination":"Leh","days":3,"createdAt":"2026-10-07T17:23:04.708Z"},{"id":"f15fea66-ad89-4f3c-9dbc-460d13a6ba6c","destination":"Hampi","days":3,"createdAt":"2026-10-07T17:23:05.262Z"}]

```

## 6. Monitoring is watching it
```text
$ curl prometheus:9090/api/v1/targets   (summarised)
  kube-state-metrics   up    http://kube-state-metrics.monitoring.svc:8080/metrics
  kubernetes-cadvisor  up    https://kubernetes.default.svc:443/api/v1/nodes/minikube/proxy/metrics/cadvisor
  kubernetes-kubelet   up    https://kubernetes.default.svc:443/api/v1/nodes/minikube/proxy/metrics
  kubernetes-pods      up    yatri-trips-5dddd95b75-krq2g
  kubernetes-pods      up    yatri-trips-5dddd95b75-457ph
  prometheus           up    http://localhost:9090/metrics

$ promql: up{app="yatri-trips"}
  app=yatri-trips,pod=yatri-trips-5dddd95b75-457ph,version=1.0.0         1.0
  app=yatri-trips,pod=yatri-trips-5dddd95b75-krq2g,version=1.0.0         1.0

$ promql: yatri_trips_stored
  app=yatri-trips,pod=yatri-trips-5dddd95b75-457ph,version=1.0.0         3.0
  app=yatri-trips,pod=yatri-trips-5dddd95b75-krq2g,version=1.0.0         3.0

$ promql: sum by (method, route, status) (increase(http_requests_total{app="yatri-trips"}[5m]))
  method=GET,route=/healthz,status=200                                   33.9232
  method=GET,route=/readyz,status=200                                    67.036
  method=GET,route=/metrics,status=200                                   20.9747
  method=GET,route=/,status=200                                          0.0
  method=POST,route=/api/trips,status=201                                0.0
  method=GET,route=/api/trips,status=200                                 0.0

$ promql: sum by (pod) (container_memory_working_set_bytes{namespace="yatri",container="api"})
  pod=yatri-trips-5dddd95b75-457ph                                       15327232.0
  pod=yatri-trips-5dddd95b75-krq2g                                       30281728.0

$ kubectl -n monitoring exec deploy/prometheus -- promtool check rules /etc/prometheus/rules/yatri.yml
Checking /etc/prometheus/rules/yatri.yml
  SUCCESS: 11 rules found


$ curl -u admin:**** grafana:3000/api/search?query=yatri
  Yatri  (folder None, uid fg0j2i2sipczkd)
  Yatri Trips - Service Overview  (folder Yatri, uid yatri-trips)

$ kubectl -n yatri logs deploy/yatri-trips --tail=4
Found 2 pods, using pod/yatri-trips-5dddd95b75-457ph
{"ts":"2026-10-07T17:20:59.487Z","level":"info","msg":"listening","service":"yatri-trips","version":"1.0.0","port":8080,"env":"production","dataDir":"/data","apiKeyConfigured":true}
{"ts":"2026-10-07T17:23:04.709Z","level":"info","msg":"request","service":"yatri-trips","version":"1.0.0","method":"POST","route":"/api/trips","status":201,"duration_ms":3}
{"ts":"2026-10-07T17:23:05.262Z","level":"info","msg":"request","service":"yatri-trips","version":"1.0.0","method":"POST","route":"/api/trips","status":201,"duration_ms":1}

```

## 7. Ship v1.0.1 - the pipeline commits the tag, Argo CD rolls it out
```text
$ bash "<platform-repo>/scripts/pipeline.sh" 1.0.1 "<platform-repo>" 2>&1 | tail -12

========== 7/8 Security gate ==========
Policy : CRITICAL <= 0, HIGH <= 5 (fixable only)
Found  : CRITICAL = 0, HIGH = 0
SECURITY GATE: PASSED

========== 8/8 Push + GitOps deploy ==========
localhost:5000/yatri-trips:1.0.1
{"name":"yatri-trips","tags":["1.0.0","1.0.1"]}

467828a deploy: yatri-trips 1.0.1
pushed - Argo CD will roll out 1.0.1

# (webhook stand-in: ask Argo CD to re-read Git now instead of waiting for its poll)
t+  1s  yatri-trips: sync=OutOfSync health=Healthy rev=467828a57918504e1ef683d91ecc7e8542053b5f
t+  4s  yatri-trips: sync=Synced health=Progressing rev=467828a57918504e1ef683d91ecc7e8542053b5f
t+ 11s  yatri-trips: sync=Synced health=Healthy rev=467828a57918504e1ef683d91ecc7e8542053b5f
$ kubectl -n yatri rollout status deploy/yatri-trips --timeout=180s
deployment "yatri-trips" successfully rolled out

$ kubectl -n yatri get pods -l app.kubernetes.io/name=yatri-trips -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready
POD                           IMAGE                                           READY
yatri-trips-c8c4f95df-9br4m   host.minikube.internal:5000/yatri-trips:1.0.1   true
yatri-trips-c8c4f95df-klwp9   host.minikube.internal:5000/yatri-trips:1.0.1   true

$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/
{"service":"yatri-trips","version":"1.0.1","env":"production"}
# trips written before the rollout are still there (PVC):
$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/api/trips | python3 -c 'import json,sys; print([t["destination"] for t in json.load(sys.stdin)])' 2>/dev/null || minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/api/trips
['Jaipur', 'Leh', 'Hampi']

$ git -C "<platform-repo>" log --oneline
467828a deploy: yatri-trips 1.0.1
94d2997 deploy: yatri-trips 1.0.0
793f2a9 Yatri platform: app, chart, monitoring, gitops

```

## 8. SAST on the application (run separately - Semgrep is not on the pipeline script's PATH on this machine)

$ semgrep scan --config p/javascript --config p/nodejs --config p/security-audit --config ../security/semgrep.yml --metrics=off src
┌─────────────┐
│ Scan Status │
└─────────────┘
  Scanning 5 files tracked by git with 295 Code rules:
  Language      Rules   Files          Origin      Rules                                                                
 ─────────────────────────────        ───────────────────                                                               
  js               84       5          Community     292                                                                
  <multilang>       2       5          Custom          3                                                                
┌──────────────┐
│ Scan Summary │
└──────────────┘
✅ Scan completed successfully.
 • Findings: 0 (0 blocking)
 • Rules run: 86
 • Targets scanned: 5
 • Parsed lines: ~100.0%
 • Scan was limited to files tracked by git
 • For a detailed list of skipped files and lines, run semgrep with the --verbose flag
Ran 86 rules on 5 files: 0 findings.
(need more rules? `semgrep login` for additional free Semgrep Registry rules)
If Semgrep missed a finding, please send us feedback to let us know!
See https://semgrep.dev/docs/reporting-false-negatives/
```

## 9. terraform/aws - init, fmt, validate (no AWS account; LocalStack's free edition has no EKS)

```text
$ terraform init
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/random versions matching "~> 3.6"...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/random v3.9.1...
- Installed hashicorp/random v3.9.1 (signed by HashiCorp)
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

$ terraform fmt -check -recursive
exit=0

$ terraform validate
Success! The configuration is valid.


$ terraform providers

Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/random] ~> 3.6
└── provider[registry.terraform.io/hashicorp/aws] ~> 5.0

```

## 10. Trivy 0.70.0 - new check KSV-0118, fixed and rolled out through GitOps

GitHub Actions now runs trivy-action v0.36.0, which installs Trivy 0.70.0.
Its newer check KSV-0118 flagged the monitoring Deployments: they hardened
each container but set no pod-level securityContext.

```text
$ trivy --version
Version: 0.70.0

# before - the pushed commit
$ trivy fs --config security/trivy.yaml --ignorefile security/.trivyignore --exit-code 1 .
  exit code: 1
  KSV-0118 HIGH  monitoring/alertmanager.yaml         Default security context configured
  KSV-0118 HIGH  monitoring/alertmanager.yaml         Default security context configured
  KSV-0118 HIGH  monitoring/grafana.yaml              Default security context configured
  KSV-0118 HIGH  monitoring/kube-state-metrics.yaml   Default security context configured
  KSV-0118 HIGH  monitoring/prometheus.yaml           Default security context configured
  findings (HIGH/CRITICAL): 5
```

Fix: a pod-level securityContext on every monitoring Deployment - run as the
image's own non-root user, fsGroup for the emptyDir volumes, RuntimeDefault
seccomp. The alert-log nginx now runs as uid 101 and listens on 8080; its
Service still exposes port 80, so the Alertmanager webhook URL is unchanged.

```text
$ git -C "<platform-repo>" diff --stat
 monitoring/alertmanager.yaml       | 18 +++++++++++++++---
 monitoring/grafana.yaml            |  6 ++++++
 monitoring/kube-state-metrics.yaml |  6 ++++++
 monitoring/prometheus.yaml         |  6 ++++++
 4 files changed, 33 insertions(+), 3 deletions(-)

$ git -C "<platform-repo>" diff -- monitoring/prometheus.yaml | grep -E '^[-+] ' | tr -d '\r'
+      securityContext:            # pod level: never root, default seccomp (Trivy KSV-0118)
+        runAsNonRoot: true
+        runAsUser: 65534
+        runAsGroup: 65534
+        fsGroup: 65534               # emptyDir volumes are writable by this group
+        seccompProfile: { type: RuntimeDefault }

$ git -C "<platform-repo>" log --oneline -1
4097b57 harden: pod-level securityContext for monitoring (Trivy KSV-0118)

$ kubectl -n argocd get application yatri-monitoring -o jsonpath='{.status.sync.revision}{" sync="}{.status.sync.status}{" health="}{.status.health.status}{"\n"}'
4097b57515164f868cfbc8a2c76679c8ad72f3f0 sync=Synced health=Progressing

Waiting for deployment "prometheus" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "prometheus" rollout to finish: 1 old replicas are pending termination...
deployment "prometheus" successfully rolled out
Waiting for deployment "alertmanager" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "alertmanager" rollout to finish: 1 old replicas are pending termination...
deployment "alertmanager" successfully rolled out
deployment "alert-log" successfully rolled out
Waiting for deployment "grafana" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "grafana" rollout to finish: 1 old replicas are pending termination...
deployment "grafana" successfully rolled out
deployment "kube-state-metrics" successfully rolled out

$ kubectl -n monitoring get pods
NAME                                  READY   STATUS        RESTARTS   AGE
alert-log-7c775bb858-zwt7x            1/1     Running       0          26s
alertmanager-976c945f9-mv86p          1/1     Running       0          26s
grafana-5579f67ccc-79qtb              1/1     Terminating   0          33m
grafana-7cf577f7c4-z6trk              1/1     Running       0          26s
kube-state-metrics-6c4c9c46d6-q724k   1/1     Running       0          26s
prometheus-6c844c799f-mg9cq           1/1     Running       0          26s

$ # pod-level securityContext now running in the cluster
  prometheus: {"fsGroup":65534,"runAsGroup":65534,"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}}
  alertmanager: {"fsGroup":65534,"runAsGroup":65534,"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}}
  alert-log: {"fsGroup":101,"runAsGroup":101,"runAsNonRoot":true,"runAsUser":101,"seccompProfile":{"type":"RuntimeDefault"}}
  grafana: {"fsGroup":472,"runAsGroup":472,"runAsNonRoot":true,"runAsUser":472,"seccompProfile":{"type":"RuntimeDefault"}}
  kube-state-metrics: {"fsGroup":65534,"runAsGroup":65534,"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}}

$ kubectl -n monitoring exec deploy/prometheus -- id
uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)

$ kubectl -n monitoring exec deploy/grafana -- id
uid=472(grafana) gid=472 groups=0(root),472

$ kubectl -n monitoring exec deploy/alert-log -- id
uid=101(nginx) gid=101(nginx) groups=101(nginx)

```

Everything still works - targets, dashboards, and the alert path end to end:

```text
$ curl prometheus:9090/api/v1/targets   (summarised)
  kube-state-metrics   up
  kubernetes-cadvisor  up
  kubernetes-kubelet   up
  kubernetes-pods      up
  kubernetes-pods      up
  prometheus           up

$ kubectl -n monitoring exec deploy/grafana -- wget -qO- http://localhost:3000/api/health | tr -d '\n '
{"database":"ok","version":"11.3.0","commit":"d9455ff7db73b694db7d412e49a68bec767f2b5a"}

$ # send a test alert to Alertmanager; it must reach alert-log on its new port
$ curl -X POST alertmanager:9093/api/v2/alerts -d '[{"labels":{"alertname":"GitOpsHardeningCheck","severity":"warning"}}]'
 (accepted)

$ kubectl -n monitoring logs deploy/alert-log --tail=50 | grep -o '"status":"[a-z]*","labels":{"alertname":"GitOpsHardeningCheck"[^}]*' | tail -1
"status":"firing","labels":{"alertname":"GitOpsHardeningCheck","severity":"warning","team":"platform"

```

The same scan as CI, after the fix:

```text
$ trivy fs --config security/trivy.yaml --ignorefile security/.trivyignore --exit-code 1 .
  exit code: 0
  findings (HIGH/CRITICAL): 0

yatri-root: sync=Synced health=Healthy
yatri-monitoring: sync=Synced health=Healthy
yatri-trips: sync=Synced health=Healthy
```

## 11. terraform/aws against LocalStack - plan everything, apply what it emulates

No AWS account is available, so the configuration was run against LocalStack
3.8.1 using [`localstack_override.tf.example`](terraform/aws/localstack_override.tf.example).

```text
$ curl -s localhost:4566/_localstack/health   (services this configuration uses)
  LocalStack 3.8.1 community
  ec2  available
  s3   available
  iam  available
  sts  available
  kms  available
  ecr  not in this edition
  eks  not in this edition

$ cp localstack_override.tf.example override.tf

$ terraform init -input=false -no-color | grep -E 'Initializing provider|Using previously|successfully initialized'
Initializing provider plugins...
- Using previously-installed hashicorp/random v3.9.1
- Using previously-installed hashicorp/aws v5.100.0
Terraform has been successfully initialized!

```

### Plan - the whole configuration

```text
$ terraform plan -input=false -no-color -out=full.tfplan | grep -E '^  # |^Plan:'
  # data.aws_iam_policy_document.ci_push will be read during apply
  # (config refers to values not yet known)
  # data.aws_iam_policy_document.github_assume will be read during apply
  # (config refers to values not yet known)
  # aws_ecr_lifecycle_policy.app will be created
  # aws_ecr_repository.app will be created
  # aws_eip.nat will be created
  # aws_eks_cluster.this will be created
  # aws_eks_node_group.default will be created
  # aws_iam_openid_connect_provider.github will be created
  # aws_iam_role.cluster will be created
  # aws_iam_role.github_ci will be created
  # aws_iam_role.node will be created
  # aws_iam_role_policy.ci_push will be created
  # aws_iam_role_policy_attachment.cluster will be created
  # aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"] will be created
  # aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"] will be created
  # aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"] will be created
  # aws_internet_gateway.this will be created
  # aws_kms_key.backups will be created
  # aws_kms_key.eks will be created
  # aws_nat_gateway.this will be created
  # aws_route_table.private will be created
  # aws_route_table.public will be created
  # aws_route_table_association.private[0] will be created
  # aws_route_table_association.private[1] will be created
  # aws_route_table_association.public[0] will be created
  # aws_route_table_association.public[1] will be created
  # aws_s3_bucket.backups will be created
  # aws_s3_bucket_public_access_block.backups will be created
  # aws_s3_bucket_server_side_encryption_configuration.backups will be created
  # aws_s3_bucket_versioning.backups will be created
  # aws_subnet.private[0] will be created
  # aws_subnet.private[1] will be created
  # aws_subnet.public[0] will be created
  # aws_subnet.public[1] will be created
  # aws_vpc.this will be created
  # random_id.suffix will be created
Plan: 34 to add, 0 to change, 0 to destroy.

```

### Apply - everything except EKS and ECR

```text
$ terraform apply -input=false -no-color -auto-approve $TARGETS 2>&1 | grep -E 'Creation complete|^Apply complete|^Error'
random_id.suffix: Creation complete after 0s [id=Q9oUpA]
aws_eip.nat: Creation complete after 0s [id=eipalloc-02f9d94a]
aws_iam_openid_connect_provider.github: Creation complete after 1s [id=arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com]
aws_iam_role.node: Creation complete after 1s [id=yatri-prod-eks-node]
aws_iam_role.cluster: Creation complete after 1s [id=yatri-prod-eks-cluster]
aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]: Creation complete after 0s [id=yatri-prod-eks-node-20261007180210870900000002]
aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]: Creation complete after 0s [id=yatri-prod-eks-node-20261007180210882400000004]
aws_iam_role_policy_attachment.cluster: Creation complete after 0s [id=yatri-prod-eks-cluster-20261007180210876500000003]
aws_iam_role.github_ci: Creation complete after 0s [id=yatri-prod-github-ci]
aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]: Creation complete after 0s [id=yatri-prod-eks-node-20261007180210860800000001]
aws_s3_bucket.backups: Creation complete after 2s [id=yatri-prod-backups-43da14a4]
aws_s3_bucket_public_access_block.backups: Creation complete after 0s [id=yatri-prod-backups-43da14a4]
aws_s3_bucket_versioning.backups: Creation complete after 1s [id=yatri-prod-backups-43da14a4]
aws_kms_key.backups: Creation complete after 10s [id=15f4f46e-f2c4-41e1-95c3-3601d787bfe2]
aws_kms_key.eks: Creation complete after 10s [id=31ec43cd-a0f4-46dd-8e8e-b2e9cd64dcf6]
aws_s3_bucket_server_side_encryption_configuration.backups: Creation complete after 0s [id=yatri-prod-backups-43da14a4]
aws_vpc.this: Creation complete after 11s [id=vpc-990d72e0]
aws_subnet.private[0]: Creation complete after 0s [id=subnet-6fb0a41f]
aws_subnet.public[1]: Creation complete after 0s [id=subnet-e81d3945]
aws_subnet.public[0]: Creation complete after 0s [id=subnet-e5cfda26]
aws_subnet.private[1]: Creation complete after 0s [id=subnet-20e9e390]
aws_internet_gateway.this: Creation complete after 0s [id=igw-b6a8dc62]
aws_nat_gateway.this: Creation complete after 1s [id=nat-1b494e3f923d23ab4]
aws_route_table.public: Creation complete after 1s [id=rtb-07ea2e86]
aws_route_table_association.public[0]: Creation complete after 0s [id=rtbassoc-74077743]
aws_route_table_association.public[1]: Creation complete after 0s [id=rtbassoc-227fdf73]
aws_route_table.private: Creation complete after 0s [id=rtb-16edc7f7]
aws_route_table_association.private[0]: Creation complete after 0s [id=rtbassoc-aaf60eba]
aws_route_table_association.private[1]: Creation complete after 0s [id=rtbassoc-bb5b80bf]
Apply complete! Resources: 29 added, 0 changed, 0 destroyed.

$ terraform state list
data.aws_availability_zones.available
data.aws_iam_policy_document.eks_assume
data.aws_iam_policy_document.github_assume
data.aws_iam_policy_document.node_assume
aws_eip.nat
aws_iam_openid_connect_provider.github
aws_iam_role.cluster
aws_iam_role.github_ci
aws_iam_role.node
aws_iam_role_policy_attachment.cluster
aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]
aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"]
aws_iam_role_policy_attachment.node["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
aws_internet_gateway.this
aws_kms_key.backups
aws_kms_key.eks
aws_nat_gateway.this
aws_route_table.private
aws_route_table.public
aws_route_table_association.private[0]
aws_route_table_association.private[1]
aws_route_table_association.public[0]
aws_route_table_association.public[1]
aws_s3_bucket.backups
aws_s3_bucket_public_access_block.backups
aws_s3_bucket_server_side_encryption_configuration.backups
aws_s3_bucket_versioning.backups
aws_subnet.private[0]
aws_subnet.private[1]
aws_subnet.public[0]
aws_subnet.public[1]
aws_vpc.this
random_id.suffix

```

### Verify through the AWS APIs (boto3 -> LocalStack)

```text
VPC     vpc-990d72e0  10.30.0.0/16  yatri-prod-vpc
  subnet  10.30.0.0/20    ap-south-1a  yatri-prod-public-ap-south-1a public IP on launch=False
  subnet  10.30.128.0/20  ap-south-1a  yatri-prod-private-ap-south-1a public IP on launch=False
  subnet  10.30.144.0/20  ap-south-1b  yatri-prod-private-ap-south-1b public IP on launch=False
  subnet  10.30.16.0/20   ap-south-1b  yatri-prod-public-ap-south-1b public IP on launch=False
  NAT     nat-1b494e3f923d23ab4  state=available  subnet=subnet-e5cfda26
  routes  yatri-prod-public-rt   0.0.0.0/0 -> igw-b6a8dc62
  routes  yatri-prod-private-rt  0.0.0.0/0 -> nat-1b494e3f923d23ab4
S3      yatri-prod-backups-43da14a4  versioning=Enabled  encryption=aws:kms  all public access blocked=True
KMS     yatri-prod backup bucket encryption  rotation=True  state=Enabled
KMS     yatri-prod EKS secrets encryption    rotation=True  state=Enabled
OIDC    token.actions.githubusercontent.com  audience=['sts.amazonaws.com']
IAM     role yatri-prod-eks-node  trusted by ec2.amazonaws.com
IAM     role yatri-prod-github-ci trusted by arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com
          StringEquals token.actions.githubusercontent.com:aud = sts.amazonaws.com
          StringLike token.actions.githubusercontent.com:sub = repo:milesmoralis2411/devops_hw:ref:refs/heads/main
IAM     role yatri-prod-eks-cluster trusted by eks.amazonaws.com
```

### Destroy

```text
$ terraform destroy -input=false -no-color -auto-approve 2>&1 | grep -E '^Destroy complete|^Error'
Destroy complete! Resources: 29 destroyed.

$ terraform state list | wc -l
0

```

### The two services LocalStack's free edition does not emulate

Run separately, after that destroy:

```text
$ terraform apply -input=false -no-color -auto-approve -target=aws_ecr_repository.app 2>&1 | grep '^Error'
Error: creating ECR Repository (yatri/yatri-trips): operation error ECR: CreateRepository, https response error StatusCode: 501, RequestID: cfc2c8c1-3dea-4b2e-a73d-d134212a0d8f, api error InternalFailure: API for service 'ecr' not yet implemented or pro feature - please check https://docs.localstack.cloud/references/coverage/ for further information

$ terraform apply -input=false -no-color -auto-approve -target=aws_eks_cluster.this 2>&1 | grep -E '^Error|Creation complete' | sed 's/ \[id=.*//'
aws_iam_role.cluster: Creation complete after 1s
aws_iam_role_policy_attachment.cluster: Creation complete after 0s
aws_kms_key.eks: Creation complete after 9s
aws_vpc.this: Creation complete after 11s
aws_subnet.public[0]: Creation complete after 0s
aws_subnet.public[1]: Creation complete after 0s
aws_subnet.private[1]: Creation complete after 0s
aws_subnet.private[0]: Creation complete after 0s
Error: creating EKS Cluster (yatri-prod): operation error EKS: CreateCluster, https response error StatusCode: 501, RequestID: 8c698db8-8c6d-40cf-8478-fa74c3ee2864, api error InternalFailure: API for service 'eks' not yet implemented or pro feature - please check https://docs.localstack.cloud/references/coverage/ for further information

$ terraform destroy -input=false -no-color -auto-approve 2>&1 | grep -E '^Destroy complete|^Error'
Destroy complete! Resources: 8 destroyed.
```

Both return HTTP 501: EKS and ECR are LocalStack Pro features. Every
resource the free edition supports was created, checked and destroyed; EKS and
ECR are covered by `validate` (section 9) and the plan above.
