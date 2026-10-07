# Evidence — GitOps with Argo CD

Executed on minikube v1.39.0 / Kubernetes v1.37.0 with Argo CD v3.5.4 and Gitea 1.27.3, 2026-10-07. Output is verbatim.

# Part A — sync from GitHub and self-healing

## Install Argo CD v3.5.4
```text
$ kubectl create namespace argocd
namespace/argocd created

# The upstream manifest sets imagePullPolicy: Always on 8 containers. The tags are pinned
# (v3.5.4) and already on the node, so for this bandwidth-limited lab they are switched to
# IfNotPresent - otherwise every Pod start waits behind the serialised kubelet pull queue.
$ curl -sL https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/install.yaml | sed 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/' | kubectl apply -n argocd --server-side -f - | tail -8
statefulset.apps/argocd-application-controller serverside-applied
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-redis-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy serverside-applied
networkpolicy.networking.k8s.io/argocd-server-network-policy serverside-applied

$ kubectl -n argocd rollout status deploy/argocd-server --timeout=900s
Waiting for deployment "argocd-server" rollout to finish: 0 of 1 updated replicas are available...
deployment "argocd-server" successfully rolled out

$ kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s
deployment "argocd-repo-server" successfully rolled out

$ kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
partitioned roll out complete: 1 new pods have been updated...

$ kubectl get pods -n argocd
NAME                                                READY   STATUS    RESTARTS      AGE
argocd-application-controller-0                     1/1     Running   0             47s
argocd-applicationset-controller-65db8d575f-sc5xr   1/1     Running   0             49s
argocd-dex-server-85b4cfbb95-czzqm                  1/1     Running   2 (39s ago)   49s
argocd-notifications-controller-5b8fb55fb8-tngz6    1/1     Running   0             48s
argocd-redis-6649bf858-bdnll                        1/1     Running   0             48s
argocd-repo-server-7659785968-5h75l                 1/1     Running   0             48s
argocd-server-5bb97557d-vs27k                       1/1     Running   0             47s

$ kubectl get crd applications.argoproj.io
NAME                       SCOPE        VERSIONS            CREATED AT
applications.argoproj.io   Namespaced   v1alpha1(storage)   2026-10-07T16:30:12Z

# Slow-link tuning: git fetch of the ~8 MB repo exceeded the 90s default exec timeout
$ kubectl -n argocd set env deploy/argocd-repo-server ARGOCD_EXEC_TIMEOUT=5m
deployment.apps/argocd-repo-server env updated

$ kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p '{"data":{"controller.repo.server.timeout.seconds":"300"}}'
configmap/argocd-cmd-params-cm patched

$ kubectl -n argocd rollout restart statefulset argocd-application-controller
statefulset.apps/argocd-application-controller restarted

$ kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
Waiting for deployment "argocd-repo-server" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "argocd-repo-server" rollout to finish: 1 old replicas are pending termination...
deployment "argocd-repo-server" successfully rolled out

```

## Declare the desired state: an Application pointing at Git
```text
$ cat argocd/application-live-demo.yaml
# Used for the live demo: tracks a path that is already pushed to GitHub, so
# Argo CD has real Git content to reconcile against.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-gitops-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/milesmoralis2411/devops_hw.git
    targetRevision: main
    path: 09-kubernetes-pods-replicasets-deployments/03-deployment
  destination:
    server: https://kubernetes.default.svc
    namespace: gitops-demo
  syncPolicy:
    automated:
      prune: true        # delete objects that were removed from Git
      selfHeal: true     # undo changes made to the cluster by hand
    syncOptions:
      - CreateNamespace=true

$ kubectl apply -f argocd/application-live-demo.yaml
application.argoproj.io/nginx-gitops-demo created

$ kubectl get applications -n argocd
NAME                SYNC STATUS   HEALTH STATUS
nginx-gitops-demo   Synced        Healthy

$ argo status
sync=Synced health=Healthy revision=47f0f69a5754627d645a2a15e20cef6a33331028

$ kubectl get deploy,pods -n gitops-demo
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   3/3     3            3           6s

NAME                                    READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-5c85f6ff4d-k2q64   1/1     Running   0          6s
pod/nginx-deployment-5c85f6ff4d-xmm59   1/1     Running   0          6s
pod/nginx-deployment-5c85f6ff4d-ztpkz   1/1     Running   0          6s

```

## Continuous reconciliation 1: someone scales by hand
```text
$ kubectl -n gitops-demo scale deploy/nginx-deployment --replicas=1
deployment.apps/nginx-deployment scaled

$ kubectl -n gitops-demo get deploy nginx-deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   1/1     1            1           6s

# Git says replicas: 3. selfHeal notices the drift and reverts it:
$ kubectl -n gitops-demo get deploy nginx-deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           9s

$ kubectl -n argocd get application nginx-gitops-demo -o jsonpath='{range .status.history[*]}{.id} {.revision} {.deployedAt}{"\n"}{end}'
0 47f0f69a5754627d645a2a15e20cef6a33331028 2026-10-07T16:32:29Z

```

## Continuous reconciliation 2: someone changes the image by hand
```text
$ kubectl -n gitops-demo set image deploy/nginx-deployment nginx=nginx:1.26-alpine
deployment.apps/nginx-deployment image updated

$ kubectl -n gitops-demo get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
nginx:1.25-alpine

# reverted to what Git declares:
$ kubectl -n gitops-demo get deploy nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
nginx:1.25-alpine

$ kubectl -n gitops-demo rollout status deploy/nginx-deployment --timeout=120s
deployment "nginx-deployment" successfully rolled out

```

## Continuous reconciliation 3: someone deletes the Deployment
```text
$ kubectl -n gitops-demo delete deploy nginx-deployment
deployment.apps "nginx-deployment" deleted from gitops-demo namespace

$ kubectl -n gitops-demo get deploy nginx-deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           1s

$ kubectl -n gitops-demo rollout status deploy/nginx-deployment --timeout=120s
deployment "nginx-deployment" successfully rolled out

```

## Argo CD's view of events
```text
$ kubectl -n argocd get events --field-selector involvedObject.name=nginx-gitops-demo --sort-by=.lastTimestamp | tail -12
8s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated sync status: Synced -> OutOfSync
8s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated health status: Healthy -> Progressing
8s          Normal   OperationCompleted   application/nginx-gitops-demo   Partial sync operation to 47f0f69a5754627d645a2a15e20cef6a33331028 succeeded
8s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated sync status: OutOfSync -> Synced
8s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated health status: Progressing -> Healthy
5s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated sync status: Synced -> OutOfSync
5s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated health status: Healthy -> Missing
2s          Normal   OperationStarted     application/nginx-gitops-demo   Initiated automated sync to '47f0f69a5754627d645a2a15e20cef6a33331028'
2s          Normal   OperationCompleted   application/nginx-gitops-demo   Partial sync operation to 47f0f69a5754627d645a2a15e20cef6a33331028 succeeded
2s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated sync status: OutOfSync -> Synced
2s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated health status: Missing -> Progressing
1s          Normal   ResourceUpdated      application/nginx-gitops-demo   Updated health status: Progressing -> Healthy

$ kubectl -n argocd get application nginx-gitops-demo -o jsonpath='{.status.operationState.message}'; echo
successfully synced (all tasks run)

$ argo status
sync=Synced health=Healthy revision=47f0f69a5754627d645a2a15e20cef6a33331028

```

## Argo CD UI access
```text
$ kubectl -n argocd get svc argocd-server
NAME            TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
argocd-server   ClusterIP   10.96.91.77   <none>        80/TCP,443/TCP   2m32s

$ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d   # (value not shown)
$ kubectl -n argocd port-forward svc/argocd-server 8443:443        # then open https://localhost:8443
```

## Removing the Application (no finalizer, so workloads are left in place)
```text
$ kubectl delete -f argocd/application-live-demo.yaml
application.argoproj.io "nginx-gitops-demo" deleted from argocd namespace

$ kubectl get applications -n argocd
No resources found in argocd namespace.

```

# Part B — the commit → sync → revert → prune loop

## Part B - in-cluster Git server, Argo CD polling every 20s
```text
$ kubectl apply -f git-server/gitea.yaml
namespace/gitea created
deployment.apps/gitea created
service/gitea created

$ kubectl -n gitea rollout status deploy/gitea --timeout=600s
Waiting for deployment "gitea" rollout to finish: 0 of 1 updated replicas are available...
deployment "gitea" successfully rolled out

created Gitea user 'yatri' (password generated at runtime, not shown)
$ kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"20s"}}'
configmap/argocd-cm patched (no change)

$ kubectl -n argocd rollout restart statefulset argocd-application-controller
statefulset.apps/argocd-application-controller restarted

$ kubectl -n argocd rollout status statefulset argocd-application-controller --timeout=300s
Waiting for partitioned roll out to finish: 0 out of 1 new pods have been updated...
Waiting for 1 pods to be ready...
Waiting for 1 pods to be ready...
Waiting for 1 pods to be ready...
partitioned roll out complete: 1 new pods have been updated...

```

## 1. Commit the desired state and push it
```text
$ git commit -m "Desired state v1: yatri-gitops, 2 replicas"
$ git -C "$WORK" log --oneline
1b64fbb Desired state v1: yatri-gitops, 2 replicas

$ git push http://yatri:****@localhost:3300/yatri/gitops-demo.git main

```

## 2. Point Argo CD at the repository
```text
$ cat argocd/application-gitea.yaml
# Same Application shape as application.yaml, but the source is the in-cluster
# Gitea repository the demo pushes commits to.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: yatri-gitops
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.gitea.svc.cluster.local:3000/yatri/gitops-demo.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: yatri-gitops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    # A bad commit fails fast (3 attempts within ~20s) instead of retrying
    # for minutes and holding up the fix that follows it.
    retry:
      limit: 2
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 20s

$ kubectl apply -f argocd/application-gitea.yaml
application.argoproj.io/yatri-gitops created

t+  1s  sync= health= revision=
t+  3s  sync=Synced health=Progressing revision=1b64fbb9bba3024c693b26b5f0259fe45383cb1f
t+  6s  sync=Synced health=Healthy revision=1b64fbb9bba3024c693b26b5f0259fe45383cb1f
$ kubectl -n yatri-gitops get deploy,pods,svc
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-gitops   2/2     2            2           4s

NAME                               READY   STATUS    RESTARTS   AGE
pod/yatri-gitops-578948c95-bdv6r   1/1     Running   0          4s
pod/yatri-gitops-578948c95-fdhk7   1/1     Running   0          4s

NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/yatri-gitops   ClusterIP   10.111.155.108   <none>        80/TCP    4s

$ kubectl -n yatri-gitops exec deploy/yatri-gitops -- wget -qO- localhost | grep Version
Version: v1

```

## 3. Change the desired state IN GIT (no kubectl) - Argo CD polls and syncs
```text
$ git -C "$WORK" diff | grep -E '^[-+][^-+]'
-    <p>Version: v1</p>
+    <p>Version: v2</p>
-  replicas: 2              # change this in Git -> Argo CD scales the cluster
+  replicas: 4              # change this in Git -> Argo CD scales the cluster

$ git commit -am "Release v2: 4 replicas, new content"
$ git -C "$WORK" log --oneline
38abed7 Release v2: 4 replicas, new content
1b64fbb Desired state v1: yatri-gitops, 2 replicas

$ git push

# no webhook here: Argo CD finds the commit on its own (20s polling + the repo-server revision cache)
t+  1s  sync=Synced health=Healthy revision=1b64fbb9bba3024c693b26b5f0259fe45383cb1f
t+193s  sync=Synced health=Progressing revision=38abed7a798ff01675a288ca79711c9e27bdf408
t+195s  sync=Synced health=Healthy revision=38abed7a798ff01675a288ca79711c9e27bdf408
$ kubectl -n yatri-gitops get deploy yatri-gitops
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
yatri-gitops   4/4     4            4           3m22s

$ kubectl -n yatri-gitops exec deploy/yatri-gitops -- wget -qO- localhost | grep Version
Version: v2

```

## 4. A bad commit - Argo CD refuses it and the cluster keeps running
```text
$ git -C "$WORK" diff | grep -E '^[-+][^-+]'
-apiVersion: v1
+apiVersion: v2

$ git commit -am "Tidy configmap"
$ git push   (+ webhook-style refresh from here on)

$ argo status
sync=OutOfSync health=Healthy revision=a60bdcdf5d58436c2ecf602de2a31ddceb027406
$ kubectl -n argocd get application yatri-gitops -o jsonpath='{.status.operationState.phase}: {.status.operationState.message}{"\n"}{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}'
Running: one or more synchronization tasks are not valid: failed to discover server resources for group version v2: the server could not find the requested resource. Retrying attempt #1 at 5:10PM.

# the running workload is untouched - still the last good state
$ kubectl -n yatri-gitops get deploy yatri-gitops
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
yatri-gitops   4/4     4            4           4m35s

$ kubectl -n yatri-gitops exec deploy/yatri-gitops -- wget -qO- localhost | grep Version
Version: v2

# fix forward: revert the bad commit
$ git -C "$WORK" log --oneline -3
7361617 Revert "Tidy configmap"
a60bdcd Tidy configmap
38abed7 Release v2: 4 replicas, new content

$ git push

t+  0s  sync=Synced health=Healthy revision=7361617caf4e6b361dab01d562e6488b36d3583e
```

## 5. Roll back release v2 with git revert
```text
$ git -C "$WORK" log --oneline -2
ff75d4c Revert "Release v2: 4 replicas, new content"
7361617 Revert "Tidy configmap"

$ git -C "$WORK" show --stat HEAD | tail -3
 manifests/configmap.yaml  | 2 +-
 manifests/deployment.yaml | 2 +-
 2 files changed, 2 insertions(+), 2 deletions(-)

$ git push

t+  0s  sync=OutOfSync health=Healthy revision=ff75d4c141d811ca299e62c4e2e1c4555b85e2c1
t+ 23s  sync=Synced health=Healthy revision=ff75d4c141d811ca299e62c4e2e1c4555b85e2c1
$ kubectl -n yatri-gitops get deploy yatri-gitops
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
yatri-gitops   2/2     2            2           5m2s

$ kubectl -n yatri-gitops exec deploy/yatri-gitops -- wget -qO- localhost | grep Version
Version: v1

```

## 6. Prune - delete a file from Git and the object disappears
```text
$ kubectl -n yatri-gitops get svc
NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
yatri-gitops   ClusterIP   10.111.155.108   <none>        80/TCP    5m35s

$ git -C "$WORK" log --oneline -1
a522729 Remove the Service

$ git push

t+  2s  sync=Synced health=Healthy revision=a522729bcc80b6d69f08d7a6f92756cd50f8da2a
$ kubectl -n yatri-gitops get svc
No resources found in yatri-gitops namespace.

```

## 7. Git history = deployment history
```text
$ git -C "$WORK" log --oneline
a522729 Remove the Service
ff75d4c Revert "Release v2: 4 replicas, new content"
7361617 Revert "Tidy configmap"
a60bdcd Tidy configmap
38abed7 Release v2: 4 replicas, new content
1b64fbb Desired state v1: yatri-gitops, 2 replicas

$ kubectl -n argocd get application yatri-gitops -o jsonpath='{range .status.history[*]}{.id}  {.revision}  {.deployedAt}{"\n"}{end}'
0  1b64fbb9bba3024c693b26b5f0259fe45383cb1f  2026-10-07T17:06:22Z
1  38abed7a798ff01675a288ca79711c9e27bdf408  2026-10-07T17:09:40Z
2  ff75d4c141d811ca299e62c4e2e1c4555b85e2c1  2026-10-07T17:11:23Z
3  a522729bcc80b6d69f08d7a6f92756cd50f8da2a  2026-10-07T17:12:00Z

```
