# Evidence — Minikube and the Kubernetes Basics tutorial

Executed 2026-10-08 on minikube v1.39.0 (Kubernetes v1.37.0, containerd, Docker driver).
Output is verbatim (terminal colour codes removed); lines starting with `#` are notes.
The commands are also listed in [running.md](running.md).

## 1. Minikube installed and configured
```text
$ minikube version
minikube version: v1.39.0
commit: 7a9f6a841470a207de8cf4bafcccee0969d8ba10

$ kubectl version --client
Client Version: v1.36.1
Kustomize Version: v5.8.1

$ minikube profile list
┌──────────┬────────┬────────────┬──────────────┬─────────┬────────┬───────┬────────────────┬────────────────────┐
│ PROFILE  │ DRIVER │  RUNTIME   │      IP      │ VERSION │ STATUS │ NODES │ ACTIVE PROFILE │ ACTIVE KUBECONTEXT │
├──────────┼────────┼────────────┼──────────────┼─────────┼────────┼───────┼────────────────┼────────────────────┤
│ minikube │ docker │ containerd │ 192.168.49.2 │ v1.37.0 │ OK     │ 1     │ *              │ *                  │
└──────────┴────────┴────────────┴──────────────┴─────────┴────────┴───────┴────────────────┴────────────────────┘

# the configuration this cluster was started with (minikube start --driver=docker
#   --container-runtime=containerd --kubernetes-version=v1.37.0 --cpus=2 --memory=4096):
$ python -c "import json,os; c=json.load(open(os.path.expanduser(r'~/.minikube/profiles/minikube/config.json'))); k=c['KubernetesConfig']; print('driver=%s  runtime=%s  kubernetes=%s  cpus=%s  memory=%sMB' % (c['Driver'], k['ContainerRuntime'], k['KubernetesVersion'], c['CPUs'], c['Memory']))"
driver=docker  runtime=containerd  kubernetes=v1.37.0  cpus=2  memory=4096MB

$ minikube addons list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'enabled' | cut -c1-60
│ default-storageclass        │ minikube │ enabled ✅
│ metrics-server              │ minikube │ enabled ✅
│ storage-provisioner         │ minikube │ enabled ✅

$ kubectl -n ingress-nginx get deploy ingress-nginx-controller -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d@ -f1; echo
registry.k8s.io/ingress-nginx/controller:v1.15.1


$ kubectl get ingressclass
NAME              CONTROLLER             PARAMETERS   AGE
nginx (default)   k8s.io/ingress-nginx   <none>       5h13m

```
## 2. Verify the cluster status
```text
$ minikube status
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured


$ kubectl config current-context
minikube

$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:63561
CoreDNS is running at https://127.0.0.1:63561/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                              CONTAINER-RUNTIME
minikube   Ready    control-plane   5h9m   v1.37.0   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   6.18.33.2-microsoft-standard-WSL2 (amd64)   containerd://2.3.4

$ kubectl get --raw='/readyz?verbose' | tail -4
[+]poststarthook/apiservice-openapi-controller ok
[+]poststarthook/apiservice-openapiv3-controller ok
[+]shutdown ok
readyz check passed

$ kubectl get pods -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-zndtf           1/1     Running   0          5h9m
etcd-minikube                      1/1     Running   0          5h9m
kindnet-vmzdc                      1/1     Running   0          5h9m
kube-apiserver-minikube            1/1     Running   0          5h9m
kube-controller-manager-minikube   1/1     Running   0          5h9m
kube-proxy-jwxdw                   1/1     Running   0          5h9m
kube-scheduler-minikube            1/1     Running   0          5h9m
metrics-server-768f9f6999-gmvx9    1/1     Running   0          5h9m
storage-provisioner                1/1     Running   0          5h9m

```

## Basics 1 - Deploy an app
```text
$ kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1
deployment.apps/kubernetes-bootcamp created

$ kubectl rollout status deployment/kubernetes-bootcamp --timeout=300s
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 0 of 1 updated replicas are available...
deployment "kubernetes-bootcamp" successfully rolled out

$ kubectl get deployments
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   1/1     1            1           1s

```

## Basics 2 - Explore the app: Pods and nodes
```text
$ kubectl get pods -o wide
NAME                                   READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
kubernetes-bootcamp-5cc66bcc9b-mmfgc   1/1     Running   0          2s    10.244.0.53   minikube   <none>           <none>

$ kubectl describe pod kubernetes-bootcamp-5cc66bcc9b-mmfgc | sed -n '/^Containers:/,/^Conditions:/p' | head -16
Containers:
  kubernetes-bootcamp:
    Container ID:   containerd://9546eec419bab75ec90df1b3efbc3036e35f8a033f82e66877d727fa844deb61
    Image:          gcr.io/google-samples/kubernetes-bootcamp:v1
    Image ID:       gcr.io/google-samples/kubernetes-bootcamp@sha256:0d6b8ee63bb57c5f5b6156f446b3bc3b3c143d233037f3a2f00e279c8fcc64af
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Thu, 08 Oct 2026 01:41:33 +0530
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-nxkj8 (ro)
Conditions:

$ kubectl logs kubernetes-bootcamp-5cc66bcc9b-mmfgc
Kubernetes Bootcamp App Started At: 2026-10-07T20:11:33.811Z | Running On:  kubernetes-bootcamp-5cc66bcc9b-mmfgc 


$ kubectl exec kubernetes-bootcamp-5cc66bcc9b-mmfgc -- env | grep -E '^(HOSTNAME|KUBERNETES_SERVICE_HOST|NPM_CONFIG_LOGLEVEL)='
HOSTNAME=kubernetes-bootcamp-5cc66bcc9b-mmfgc
NPM_CONFIG_LOGLEVEL=info
KUBERNETES_SERVICE_HOST=10.96.0.1

$ kubectl exec kubernetes-bootcamp-5cc66bcc9b-mmfgc -- curl -s http://localhost:8080
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1

```

## Basics 3 - Expose the app with a Service, and use labels
```text
$ kubectl expose deployment/kubernetes-bootcamp --type=NodePort --port 8080
service/kubernetes-bootcamp exposed

$ kubectl get services kubernetes-bootcamp
NAME                  TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes-bootcamp   NodePort   10.97.183.51   <none>        8080:30820/TCP   0s

$ export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -o go-template='{{(index .spec.ports 0).nodePort}}'); echo $NODE_PORT
30820

$ minikube ssh -- curl -s http://localhost:30820
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1

$ kubectl describe deployment kubernetes-bootcamp | grep -E '^(Labels|Selector):'
Labels:                 app=kubernetes-bootcamp
Selector:               app=kubernetes-bootcamp

$ kubectl label pods kubernetes-bootcamp-5cc66bcc9b-mmfgc version=v1
pod/kubernetes-bootcamp-5cc66bcc9b-mmfgc labeled

$ kubectl get pods -l version=v1
NAME                                   READY   STATUS    RESTARTS   AGE
kubernetes-bootcamp-5cc66bcc9b-mmfgc   1/1     Running   0          7s

$ kubectl delete service -l app=kubernetes-bootcamp
service "kubernetes-bootcamp" deleted from default namespace

$ minikube ssh -- "curl -s -m 3 http://localhost:30820 || echo 'curl: connection refused - nothing listens on the NodePort any more'"
curl: connection refused - nothing listens on the NodePort any more

$ kubectl exec kubernetes-bootcamp-5cc66bcc9b-mmfgc -- curl -s http://localhost:8080; echo '   <- the app itself is still running'
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1
   <- the app itself is still running

```

## Basics 4 - Scale the app
```text
# the Service from step 3 is re-created first, so there is something to load-balance
$ kubectl scale deployments/kubernetes-bootcamp --replicas=4
deployment.apps/kubernetes-bootcamp scaled

$ kubectl rollout status deployment/kubernetes-bootcamp --timeout=180s
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 3 of 4 updated replicas are available...
deployment "kubernetes-bootcamp" successfully rolled out

$ kubectl get deployments
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
kubernetes-bootcamp   4/4     4            4           12s

$ kubectl get pods -o wide
NAME                                   READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
kubernetes-bootcamp-5cc66bcc9b-jhrml   1/1     Running   0          3s    10.244.0.56   minikube   <none>           <none>
kubernetes-bootcamp-5cc66bcc9b-mmfgc   1/1     Running   0          13s   10.244.0.53   minikube   <none>           <none>
kubernetes-bootcamp-5cc66bcc9b-ppmdq   1/1     Running   0          3s    10.244.0.55   minikube   <none>           <none>
kubernetes-bootcamp-5cc66bcc9b-thbww   1/1     Running   0          3s    10.244.0.54   minikube   <none>           <none>

$ kubectl describe deployments/kubernetes-bootcamp | sed -n '/^Events:/,$p'
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  13s   deployment-controller  Scaled up replica set kubernetes-bootcamp-5cc66bcc9b from 0 to 1
  Normal  ScalingReplicaSet  3s    deployment-controller  Scaled up replica set kubernetes-bootcamp-5cc66bcc9b from 1 to 4

$ for i in 1 2 3 4 5 6 7 8; do minikube ssh -- curl -s http://localhost:$NODE_PORT; done   # the Service spreads requests
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-ppmdq | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-ppmdq | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-ppmdq | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-mmfgc | v=1
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5cc66bcc9b-thbww | v=1

$ kubectl scale deployments/kubernetes-bootcamp --replicas=2
deployment.apps/kubernetes-bootcamp scaled

$ kubectl get pods -o wide
NAME                                   READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
kubernetes-bootcamp-5cc66bcc9b-jhrml   1/1     Running   0          44s   10.244.0.56   minikube   <none>           <none>
kubernetes-bootcamp-5cc66bcc9b-mmfgc   1/1     Running   0          54s   10.244.0.53   minikube   <none>           <none>

```

## Basics 5 - Update the app, then roll back a bad update
```text
$ kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2
deployment.apps/kubernetes-bootcamp image updated

$ kubectl rollout status deployments/kubernetes-bootcamp --timeout=300s
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "kubernetes-bootcamp" rollout to finish: 1 old replicas are pending termination...
deployment "kubernetes-bootcamp" successfully rolled out

$ kubectl get pods -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                                    IMAGE                                        STATUS
kubernetes-bootcamp-5b97597885-5hs5f   docker.io/jocatalin/kubernetes-bootcamp:v2   Running
kubernetes-bootcamp-5b97597885-xgv4w   docker.io/jocatalin/kubernetes-bootcamp:v2   Running

$ minikube ssh -- curl -s http://localhost:30207
Hello Kubernetes bootcamp! | Running on: kubernetes-bootcamp-5b97597885-5hs5f | v=2

# now a broken update: the v10 tag does not exist
$ kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=gcr.io/google-samples/kubernetes-bootcamp:v10
deployment.apps/kubernetes-bootcamp image updated

$ kubectl get pods
NAME                                   READY   STATUS             RESTARTS   AGE
kubernetes-bootcamp-556487b4d4-kwfmv   0/1     ImagePullBackOff   0          26s
kubernetes-bootcamp-5b97597885-5hs5f   1/1     Running            0          60s
kubernetes-bootcamp-5b97597885-xgv4w   1/1     Running            0          60s

$ kubectl describe pods -l app=kubernetes-bootcamp | grep -E 'Failed|BackOff' | head -3
      Reason:       ImagePullBackOff

$ kubectl rollout undo deployments/kubernetes-bootcamp
deployment.apps/kubernetes-bootcamp rolled back

$ kubectl rollout status deployments/kubernetes-bootcamp --timeout=180s
deployment "kubernetes-bootcamp" successfully rolled out

$ kubectl get pods -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                                    IMAGE                                        STATUS
kubernetes-bootcamp-5b97597885-5hs5f   docker.io/jocatalin/kubernetes-bootcamp:v2   Running
kubernetes-bootcamp-5b97597885-xgv4w   docker.io/jocatalin/kubernetes-bootcamp:v2   Running

$ kubectl rollout history deployments/kubernetes-bootcamp
deployment.apps/kubernetes-bootcamp 
REVISION  CHANGE-CAUSE
1         <none>
3         <none>
4         <none>


```
