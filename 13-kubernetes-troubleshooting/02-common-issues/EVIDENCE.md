# Evidence — Common Kubernetes issues

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), 2026-10-07. Output is verbatim.

## 01 - CrashLoopBackOff
```text
$ kubectl apply -f 01-crashloopbackoff/broken.yaml
deployment.apps/crashloop-demo created

# 1. Identify
$ kubectl get pods -l app=crashloop-demo
NAME                             READY   STATUS   RESTARTS      AGE
crashloop-demo-7d5d6889f-g4nrm   0/1     Error    3 (31s ago)   45s

# 2. Investigate
$ kubectl logs crashloop-demo-7d5d6889f-g4nrm
FATAL: config file /etc/app/config.yaml not found
starting up

$ kubectl get pod crashloop-demo-7d5d6889f-g4nrm -o jsonpath='lastState={.status.containerStatuses[0].lastState.terminated.reason} exitCode={.status.containerStatuses[0].lastState.terminated.exitCode} restarts={.status.containerStatuses[0].restartCount}'; echo
lastState=Error exitCode=1 restarts=3

$ kubectl describe pod crashloop-demo-7d5d6889f-g4nrm | sed -n '/^Events:/,$p' | tail -4
  Normal   Pulled     4s (x4 over 45s)  kubelet            spec.containers{app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
  Normal   Created    4s (x4 over 45s)  kubelet            spec.containers{app}: Container created
  Normal   Started    3s (x4 over 45s)  kubelet            spec.containers{app}: Container started
  Warning  BackOff    2s (x4 over 43s)  kubelet            spec.containers{app}: Back-off restarting failed container app in pod crashloop-demo-7d5d6889f-g4nrm_default(47c09da8-7e15-4ecc-9f75-886e16921da3)

# 3. Root cause: the process exits 1 because /etc/app/config.yaml is missing
# 4. Fix
$ kubectl apply -f 01-crashloopbackoff/fixed.yaml
configmap/crashloop-config created
deployment.apps/crashloop-demo configured

$ kubectl rollout status deploy/crashloop-demo --timeout=120s
Waiting for deployment "crashloop-demo" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "crashloop-demo" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "crashloop-demo" rollout to finish: 1 old replicas are pending termination...
deployment "crashloop-demo" successfully rolled out

# 5. Verify
$ kubectl get pods -l app=crashloop-demo
NAME                              READY   STATUS        RESTARTS      AGE
crashloop-demo-658957758f-p9gt9   1/1     Running       0             2s
crashloop-demo-7d5d6889f-g4nrm    0/1     Terminating   3 (35s ago)   49s

$ kubectl logs deploy/crashloop-demo
Found 2 pods, using pod/crashloop-demo-658957758f-p9gt9
app: demo
port: 8080
started OK

```

## 02 - ImagePullBackOff (tag does not exist)
```text
$ kubectl apply -f 02-imagepullbackoff/broken.yaml
pod/imagepull-demo created

# 1. Identify
$ kubectl get pod imagepull-demo
NAME             READY   STATUS             RESTARTS   AGE
imagepull-demo   0/1     ImagePullBackOff   0          19s

# 2. Investigate
$ kubectl describe pod imagepull-demo | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  20s               default-scheduler  Successfully assigned default/imagepull-demo to minikube
  Warning  Failed     17s               kubelet            spec.containers{app}: Failed to pull image "nginx:this-tag-does-not-exist": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/library/nginx:this-tag-does-not-exist": failed to resolve reference "docker.io/library/nginx:this-tag-does-not-exist": docker.io/library/nginx:this-tag-does-not-exist: not found
  Warning  Failed     17s               kubelet            spec.containers{app}: Error: ErrImagePull
  Normal   BackOff    16s               kubelet            spec.containers{app}: Back-off pulling image "nginx:this-tag-does-not-exist"
  Warning  Failed     16s               kubelet            spec.containers{app}: Error: ImagePullBackOff
  Normal   Pulling    2s (x2 over 19s)  kubelet            spec.containers{app}: Pulling image "nginx:this-tag-does-not-exist"

# 3. Root cause: nginx:this-tag-does-not-exist - repository exists, tag does not
# 4. Fix
$ kubectl apply -f 02-imagepullbackoff/fixed.yaml
pod/imagepull-demo-fixed created

$ kubectl wait --for=condition=Ready pod/imagepull-demo-fixed --timeout=120s
pod/imagepull-demo-fixed condition met

# 5. Verify
$ kubectl get pod imagepull-demo imagepull-demo-fixed
NAME                   READY   STATUS             RESTARTS   AGE
imagepull-demo         0/1     ImagePullBackOff   0          21s
imagepull-demo-fixed   1/1     Running            0          1s

```

## 03 - ErrImagePull (repository does not exist)
```text
$ kubectl apply -f 03-errimagepull/broken.yaml
pod/errimage-demo created

# 1. Identify - caught on the first failed attempt, before the back-off kicks in
$ kubectl get pod errimage-demo
NAME            READY   STATUS         RESTARTS   AGE
errimage-demo   0/1     ErrImagePull   0          4s

# 2. Investigate
$ kubectl describe pod errimage-demo | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age   From               Message
  ----     ------     ----  ----               -------
  Normal   Scheduled  5s    default-scheduler  Successfully assigned default/errimage-demo to minikube
  Normal   Pulling    3s    kubelet            spec.containers{app}: Pulling image "ghcr.io/no-such-org-24bcs10326/no-such-image:v1"
  Warning  Failed     3s    kubelet            spec.containers{app}: Failed to pull image "ghcr.io/no-such-org-24bcs10326/no-such-image:v1": failed to pull and unpack image "ghcr.io/no-such-org-24bcs10326/no-such-image:v1": failed to resolve reference "ghcr.io/no-such-org-24bcs10326/no-such-image:v1": failed to authorize: failed to fetch anonymous token: unexpected status from GET request to https://ghcr.io/token?scope=repository%3Ano-such-org-24bcs10326%2Fno-such-image%3Apull&service=ghcr.io: 403 Forbidden
  Warning  Failed     3s    kubelet            spec.containers{app}: Error: ErrImagePull
  Normal   BackOff    2s    kubelet            spec.containers{app}: Back-off pulling image "ghcr.io/no-such-org-24bcs10326/no-such-image:v1"
  Warning  Failed     2s    kubelet            spec.containers{app}: Error: ImagePullBackOff

# 3. Root cause: the repository itself does not exist (or is private with no imagePullSecret)
# 4. Fix
$ kubectl apply -f 03-errimagepull/fixed.yaml
pod/errimage-demo-fixed created

$ kubectl wait --for=condition=Ready pod/errimage-demo-fixed --timeout=120s
pod/errimage-demo-fixed condition met

# 5. Verify
$ kubectl get pod errimage-demo errimage-demo-fixed
NAME                  READY   STATUS         RESTARTS   AGE
errimage-demo         0/1     ErrImagePull   0          8s
errimage-demo-fixed   1/1     Running        0          3s

```

## 04 - Pending
```text
$ kubectl apply -f 04-pending/broken.yaml -f 04-pending/broken-nodeselector.yaml
pod/pending-demo created
pod/pending-nodeselector created

# 1. Identify
$ kubectl get pod pending-demo pending-nodeselector -o wide
NAME                   READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE   READINESS GATES
pending-demo           0/1     Pending   0          8s    <none>   <none>   <none>           <none>
pending-nodeselector   0/1     Pending   0          8s    <none>   <none>   <none>           <none>

# 2. Investigate
$ kubectl describe pod pending-demo | sed -n '/^Events:/,$p'
Events:
  Type     Reason            Age              From               Message
  ----     ------            ----             ----               -------
  Warning  FailedScheduling  9s (x3 over 9s)  default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

$ kubectl describe pod pending-nodeselector | sed -n '/^Events:/,$p'
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  9s    default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

$ kubectl describe node minikube | sed -n '/Allocated resources:/,/Events:/p'
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                3080m (12%)  5700m (23%)
  memory             558Mi (7%)   412Mi (5%)
  ephemeral-storage  0 (0%)       0 (0%)
  hugepages-1Gi      0 (0%)       0 (0%)
  hugepages-2Mi      0 (0%)       0 (0%)
Events:

$ kubectl get nodes --show-labels
NAME       STATUS   ROLES           AGE   VERSION   LABELS
minikube   Ready    control-plane   49m   v1.37.0   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=minikube,kubernetes.io/os=linux,minikube.k8s.io/commit=7a9f6a841470a207de8cf4bafcccee0969d8ba10,minikube.k8s.io/name=minikube,minikube.k8s.io/primary=true,minikube.k8s.io/updated_at=2026_10_07T20_31_36_0700,minikube.k8s.io/version=v1.39.0,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=

# 3. Root cause: (a) 64 CPU / 128Gi requested; the node has 24 CPU / ~7.6Gi, (b) nodeSelector disktype=nvme-that-does-not-exist matches no node
# 4. Fix
$ kubectl apply -f 04-pending/fixed.yaml
pod/pending-demo-fixed created

$ kubectl wait --for=condition=Ready pod/pending-demo-fixed --timeout=120s
pod/pending-demo-fixed condition met

# (b) alternatively: label a node so the selector matches
$ kubectl label node minikube disktype=nvme-that-does-not-exist
node/minikube labeled

# 5. Verify
$ kubectl get pod pending-demo pending-demo-fixed pending-nodeselector -o wide
NAME                   READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
pending-demo           0/1     Pending   0          20s   <none>         <none>     <none>           <none>
pending-demo-fixed     1/1     Running   0          10s   10.244.0.200   minikube   <none>           <none>
pending-nodeselector   1/1     Running   0          20s   10.244.0.201   minikube   <none>           <none>

$ kubectl label node minikube disktype-
node/minikube unlabeled

```

## 05 - Stuck in ContainerCreating
```text
$ kubectl apply -f 05-containercreating/broken.yaml
pod/containercreating-demo created

# 1. Identify
$ kubectl get pod containercreating-demo
NAME                     READY   STATUS              RESTARTS   AGE
containercreating-demo   0/1     ContainerCreating   0          21s

# 2. Investigate
$ kubectl describe pod containercreating-demo | sed -n '/^Events:/,$p'
Events:
  Type     Reason       Age               From               Message
  ----     ------       ----              ----               -------
  Normal   Scheduled    20s               default-scheduler  Successfully assigned default/containercreating-demo to minikube
  Warning  FailedMount  5s (x6 over 20s)  kubelet            MountVolume.SetUp failed for volume "tls" : secret "tls-certs" not found

$ kubectl get secret tls-certs
Error from server (NotFound): secrets "tls-certs" not found

# 3. Root cause: the volume references Secret tls-certs, which does not exist -> FailedMount
# 4. Fix
$ kubectl apply -f 05-containercreating/fixed.yaml
secret/tls-certs created
pod/containercreating-demo-fixed created

$ kubectl wait --for=condition=Ready pod/containercreating-demo-fixed --timeout=120s
pod/containercreating-demo-fixed condition met

# 5. Verify - and the original Pod recovers on its own once the Secret exists
$ kubectl get pod containercreating-demo containercreating-demo-fixed
NAME                           READY   STATUS    RESTARTS   AGE
containercreating-demo         1/1     Running   0          44s
containercreating-demo-fixed   1/1     Running   0          22s

$ kubectl exec containercreating-demo-fixed -- ls /etc/tls
tls.crt
tls.key

```

## 06 - Service connectivity
```text
$ kubectl apply -f 06-service-connectivity/broken.yaml
deployment.apps/svc-demo created
service/svc-demo created

$ kubectl rollout status deploy/svc-demo --timeout=120s
Waiting for deployment "svc-demo" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "svc-demo" rollout to finish: 1 of 2 updated replicas are available...
deployment "svc-demo" successfully rolled out

# 1. Identify
$ kubectl exec svc-client -- wget -qO- -T 5 http://svc-demo
wget: can't connect to remote host (10.108.173.130): Connection refused
command terminated with exit code 1

# 2. Investigate
$ kubectl exec svc-client -- nslookup svc-demo
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	svc-demo.default.svc.cluster.local
Address: 10.108.173.130

** server can't find svc-demo.cluster.local: NXDOMAIN

** server can't find svc-demo.svc.cluster.local: NXDOMAIN

** server can't find svc-demo.svc.cluster.local: NXDOMAIN

** server can't find svc-demo.cluster.local: NXDOMAIN


command terminated with exit code 1

$ kubectl get endpointslices -l kubernetes.io/service-name=svc-demo
NAME             ADDRESSTYPE   PORTS     ENDPOINTS   AGE
svc-demo-4hdff   IPv4          <unset>   <unset>     6s

$ kubectl get svc svc-demo -o jsonpath='{.spec.selector}'; echo
{"app":"web"}

$ kubectl get pods -l app=web-app --show-labels
NAME                        READY   STATUS    RESTARTS   AGE   LABELS
svc-demo-7754fb78b9-2n28f   1/1     Running   0          7s    app=web-app,pod-template-hash=7754fb78b9
svc-demo-7754fb78b9-5f9hz   1/1     Running   0          7s    app=web-app,pod-template-hash=7754fb78b9

# 3. Root cause: DNS works, but the Service selector app=web matches no Pods (they are app=web-app)
# 4. Fix
$ kubectl apply -f 06-service-connectivity/fixed.yaml
deployment.apps/svc-demo unchanged
service/svc-demo configured

# 5. Verify
$ kubectl get endpointslices -l kubernetes.io/service-name=svc-demo
NAME             ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
svc-demo-4hdff   IPv4          80      10.244.0.204,10.244.0.205   10s

$ kubectl exec svc-client -- wget -qO- -T 5 http://svc-demo | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>

# Variant: correct selector, wrong targetPort -> endpoints exist but connection refused
$ kubectl apply -f 06-service-connectivity/broken-wrong-port.yaml
service/svc-demo-wrongport created

$ kubectl get endpointslices -l kubernetes.io/service-name=svc-demo-wrongport
NAME                       ADDRESSTYPE   PORTS   ENDPOINTS                   AGE
svc-demo-wrongport-5cg4q   IPv4          8080    10.244.0.205,10.244.0.204   3s

$ kubectl exec svc-client -- wget -qO- -T 5 http://svc-demo-wrongport
wget: can't connect to remote host (10.110.173.131): Connection refused
command terminated with exit code 1

```

## 07 - DNS issues
```text
$ kubectl apply -f 07-dns-issues/broken.yaml
namespace/backend-ns created
deployment.apps/backend created
service/backend created
pod/dns-client created

$ kubectl -n backend-ns rollout status deploy/backend --timeout=120s
Waiting for deployment "backend" rollout to finish: 0 of 1 updated replicas are available...
deployment "backend" successfully rolled out

# 1. Identify
$ kubectl logs dns-client
Server:		10.96.0.10
Address:	10.96.0.10:53

** server can't find backend.cluster.local: NXDOMAIN

** server can't find backend.default.svc.cluster.local: NXDOMAIN

** server can't find backend.svc.cluster.local: NXDOMAIN

** server can't find backend.default.svc.cluster.local: NXDOMAIN

** server can't find backend.cluster.local: NXDOMAIN

** server can't find backend.svc.cluster.local: NXDOMAIN


# 2. Investigate
$ kubectl exec dns-client -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

$ kubectl get svc -A -l !component --field-selector metadata.name=backend
NAMESPACE     NAME      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
backend-ns    backend   ClusterIP   10.102.244.254   <none>        80/TCP    7s
netpol-demo   backend   ClusterIP   10.99.123.5      <none>        80/TCP    6m9s

$ kubectl get pods -n kube-system -l k8s-app=kube-dns
NAME                       READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-zndtf   1/1     Running   0          50m

# 3. Root cause: CoreDNS is healthy. The short name "backend" is expanded with the
#    client namespace (default.svc.cluster.local), but the Service lives in backend-ns.
# 4. Fix
$ kubectl apply -f 07-dns-issues/fixed.yaml
pod/dns-client-fixed created

# 5. Verify
$ kubectl logs dns-client-fixed
Server:		10.96.0.10
Address:	10.96.0.10:53


Name:	backend.backend-ns.svc.cluster.local
Address: 10.102.244.254


$ kubectl exec dns-client-fixed -- wget -qO- -T 5 http://backend.backend-ns.svc.cluster.local
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

```

## 08 - Pod networking (server bound to loopback)
```text
$ kubectl apply -f 08-pod-networking/broken.yaml
configmap/loopback-conf created
deployment.apps/loopback-web created
service/loopback-web created

$ kubectl rollout status deploy/loopback-web --timeout=120s
Waiting for deployment "loopback-web" rollout to finish: 0 of 1 updated replicas are available...
deployment "loopback-web" successfully rolled out

# 1. Identify - Running, Ready, has an endpoint... and refuses connections
$ kubectl get pods -l app=loopback-web -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
loopback-web-7bf78c57dc-nn6bp   1/1     Running   0          3s    10.244.0.210   minikube   <none>           <none>

$ kubectl get endpointslices -l kubernetes.io/service-name=loopback-web
NAME                 ADDRESSTYPE   PORTS   ENDPOINTS      AGE
loopback-web-kcdzl   IPv4          80      10.244.0.210   3s

$ kubectl exec net-client -- wget -qO- -T 5 http://loopback-web
wget: can't connect to remote host (10.98.197.82): Connection refused
command terminated with exit code 1

$ kubectl exec net-client -- wget -qO- -T 5 http://10.244.0.210
wget: can't connect to remote host (10.244.0.210): Connection refused
command terminated with exit code 1

# 2. Investigate - from INSIDE the Pod it works
$ kubectl exec loopback-web-7bf78c57dc-nn6bp -- wget -qO- http://127.0.0.1
hello from loopback-web-7bf78c57dc-nn6bp

$ kubectl exec loopback-web-7bf78c57dc-nn6bp -- netstat -tln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 127.0.0.1:80            0.0.0.0:*               LISTEN      

# 3. Root cause: nginx listens on 127.0.0.1:80, not 0.0.0.0:80. Traffic to the
#    Pod IP reaches the network namespace but nothing is bound there.
#    The exec readiness probe also runs inside the Pod, so it never noticed.
# 4. Fix
$ kubectl apply -f 08-pod-networking/fixed.yaml
configmap/loopback-conf configured
deployment.apps/loopback-web configured
service/loopback-web unchanged

$ kubectl rollout status deploy/loopback-web --timeout=120s
Waiting for deployment "loopback-web" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "loopback-web" rollout to finish: 1 old replicas are pending termination...
deployment "loopback-web" successfully rolled out

# 5. Verify
$ kubectl exec loopback-web-c9d76cdf8-v7rtn -- netstat -tln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      

$ kubectl exec net-client -- wget -qO- -T 5 http://loopback-web
hello from loopback-web-c9d76cdf8-v7rtn

```

## 08b - Pod networking variant: NetworkPolicy
```text
$ kubectl get pods -n kube-system -o name | grep -iE 'calico|cilium|kindnet'
pod/kindnet-vmzdc

# minikube is running the kindnet CNI, which does NOT enforce NetworkPolicy.
# The objects are accepted and stored, but no traffic is dropped, so this variant
# shows the inspection steps; enforcement needs e.g. minikube start --cni=calico.
$ kubectl apply -f 08-pod-networking/networkpolicy-variant/broken.yaml
namespace/netpol-demo unchanged
networkpolicy.networking.k8s.io/default-deny-all unchanged
deployment.apps/backend unchanged
service/backend unchanged
pod/frontend unchanged

$ kubectl get networkpolicy -n netpol-demo
NAME                               POD-SELECTOR   AGE
allow-dns                          <none>         6m27s
allow-frontend-egress-to-backend   app=frontend   6m27s
allow-frontend-to-backend          app=backend    6m27s
default-deny-all                   <none>         6m28s

$ kubectl describe networkpolicy default-deny-all -n netpol-demo
Name:         default-deny-all
Namespace:    netpol-demo
Created on:   2026-10-07 21:16:09 +0530 IST
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Allowing egress traffic:
    <none> (Selected pods are isolated for egress connectivity)
  Policy Types: Ingress, Egress

$ kubectl apply -f 08-pod-networking/networkpolicy-variant/fixed.yaml
networkpolicy.networking.k8s.io/allow-dns unchanged
networkpolicy.networking.k8s.io/allow-frontend-to-backend unchanged
networkpolicy.networking.k8s.io/allow-frontend-egress-to-backend unchanged

$ kubectl get networkpolicy -n netpol-demo
NAME                               POD-SELECTOR   AGE
allow-dns                          <none>         6m28s
allow-frontend-egress-to-backend   app=frontend   6m28s
allow-frontend-to-backend          app=backend    6m28s
default-deny-all                   <none>         6m29s

```

## 09 - Configuration errors
```text
$ kubectl apply -f 09-configuration/broken.yaml
configmap/app-settings created
pod/config-demo created

# 1. Identify
$ kubectl get pod config-demo
NAME          READY   STATUS              RESTARTS   AGE
config-demo   0/1     ContainerCreating   0          11s

# 2. Investigate - fix one error, the next one surfaces
$ kubectl describe pod config-demo | sed -n '/^Events:/,$p'
Events:
  Type     Reason       Age               From               Message
  ----     ------       ----              ----               -------
  Normal   Scheduled    11s               default-scheduler  Successfully assigned default/config-demo to minikube
  Warning  FailedMount  3s (x5 over 10s)  kubelet            MountVolume.SetUp failed for volume "extra" : configmap "extra-settings" not found

$ kubectl get configmap app-settings -o jsonpath='{.data}'; echo
{"log_level":"debug"}

$ kubectl get configmap extra-settings
Error from server (NotFound): configmaps "extra-settings" not found

# 3. Root causes: wrong ConfigMap key (logLevel vs log_level), missing ConfigMap
#    extra-settings, and a command (/usr/local/bin/myapp) that is not in the image
# 4. Fix
$ kubectl apply -f 09-configuration/fixed.yaml
configmap/app-settings unchanged
configmap/extra-settings created
pod/config-demo-fixed created

$ kubectl wait --for=condition=Ready pod/config-demo-fixed --timeout=120s
pod/config-demo-fixed condition met

# 5. Verify
$ kubectl get pod config-demo-fixed
NAME                READY   STATUS    RESTARTS   AGE
config-demo-fixed   1/1     Running   0          2s

$ kubectl logs config-demo-fixed
LOG_LEVEL=debug
retries = 3

# the original Pod: with extra-settings now present its volume mounts, so the NEXT error surfaces -
# the wrong key name. Bugs are revealed one at a time; the missing binary would come after that.
$ kubectl get pod config-demo
NAME          READY   STATUS                       RESTARTS   AGE
config-demo   0/1     CreateContainerConfigError   0          29s

$ kubectl describe pod config-demo | sed -n '/^Events:/,$p' | tail -3
  Warning  FailedMount  22s (x5 over 29s)  kubelet            MountVolume.SetUp failed for volume "extra" : configmap "extra-settings" not found
  Normal   Pulled       12s (x2 over 13s)  kubelet            spec.containers{app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
  Warning  Failed       12s (x2 over 13s)  kubelet            spec.containers{app}: Error: couldn't find key logLevel in ConfigMap default/app-settings

```
