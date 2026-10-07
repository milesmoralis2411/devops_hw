# Evidence — kubectl troubleshooting commands

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), 2026-10-07. Output is verbatim.

## kubectl get - what exists and what state is it in?
```text
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   28m   v1.37.0

$ kubectl get all -n ts-cmds
NAME                      READY   STATUS    RESTARTS   AGE
pod/client                1/1     Running   0          46s
pod/web-f4c54c7fc-r5d9h   1/1     Running   0          49s
pod/web-f4c54c7fc-xwgdq   1/1     Running   0          47s

NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/web   ClusterIP   10.110.103.117   <none>        80/TCP    49s

NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web   2/2     2            2           49s

NAME                             DESIRED   CURRENT   READY   AGE
replicaset.apps/web-68847bc8d4   0         0         0       49s
replicaset.apps/web-f4c54c7fc    2         2         2       49s

$ kubectl get pods -n ts-cmds --show-labels
NAME                  READY   STATUS    RESTARTS   AGE   LABELS
client                1/1     Running   0          46s   run=client
web-f4c54c7fc-r5d9h   1/1     Running   0          49s   app=web,pod-template-hash=f4c54c7fc
web-f4c54c7fc-xwgdq   1/1     Running   0          47s   app=web,pod-template-hash=f4c54c7fc

$ kubectl get pods -A --field-selector=status.phase!=Running
NAMESPACE       NAME                                       READY   STATUS              RESTARTS   AGE
default         hpa-prepull                                0/1     ContainerCreating   0          2m35s
ingress-nginx   ingress-nginx-admission-create-l8ppf       0/1     Completed           0          27m
ingress-nginx   ingress-nginx-admission-patch-xhspw        0/1     Completed           0          27m
ingress-nginx   ingress-nginx-controller-d7cd8c989-tfmp7   0/1     ContainerCreating   0          27m

$ kubectl get pod web-f4c54c7fc-r5d9h -n ts-cmds -o jsonpath='{.status.phase} {.status.podIP} {.spec.nodeName}'; echo
Running 10.244.0.104 minikube

$ kubectl get pods -n ts-cmds -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,RESTARTS:.status.containerStatuses[0].restartCount
NAME                  IMAGE               RESTARTS
client                busybox:1.36        0
web-f4c54c7fc-r5d9h   nginx:1.25-alpine   0
web-f4c54c7fc-xwgdq   nginx:1.25-alpine   0

```

## kubectl get -o wide - add IPs and node placement
```text
$ kubectl get pods -n ts-cmds -o wide
NAME                  READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
client                1/1     Running   0          47s   10.244.0.106   minikube   <none>           <none>
web-f4c54c7fc-r5d9h   1/1     Running   0          50s   10.244.0.104   minikube   <none>           <none>
web-f4c54c7fc-xwgdq   1/1     Running   0          48s   10.244.0.105   minikube   <none>           <none>

$ kubectl get svc -n ts-cmds -o wide
NAME   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
web    ClusterIP   10.110.103.117   <none>        80/TCP    50s   app=web

$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION                              CONTAINER-RUNTIME
minikube   Ready    control-plane   28m   v1.37.0   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   6.18.33.2-microsoft-standard-WSL2 (amd64)   containerd://2.3.4

```

## kubectl describe - full detail plus recent events
```text
$ kubectl describe pod web-f4c54c7fc-r5d9h -n ts-cmds
Name:             web-f4c54c7fc-r5d9h
Namespace:        ts-cmds
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Start Time:       Wed, 07 Oct 2026 20:58:52 +0530
Labels:           app=web
                  pod-template-hash=f4c54c7fc
Annotations:      <none>
Status:           Running
IP:               10.244.0.104
IPs:
  IP:           10.244.0.104
Controlled By:  ReplicaSet/web-f4c54c7fc
Containers:
  nginx:
    Container ID:   containerd://a49e4c44ce89523d52f23a10817aafb623b325ff5a9b4c03dad142dac77b28e5
    Image:          nginx:1.25-alpine
    Image ID:       docker.io/library/nginx@sha256:516475cc129da42866742567714ddc681e5eed7b9ee0b9e9c015e464b4221a00
    Port:           <none>
    Host Port:      <none>
    State:          Running
      Started:      Wed, 07 Oct 2026 20:58:54 +0530
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     100m
      memory:  64Mi
    Requests:
      cpu:        20m
      memory:     16Mi
    Environment:  <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-q696c (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       True 
  ContainersReady             True 
  PodScheduled                True 
Volumes:
  kube-api-access-q696c:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   Burstable
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  50s   default-scheduler  Successfully assigned ts-cmds/web-f4c54c7fc-r5d9h to minikube
  Normal  Pulled     48s   kubelet            spec.containers{nginx}: Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
  Normal  Created    48s   kubelet            spec.containers{nginx}: Container created
  Normal  Started    48s   kubelet            spec.containers{nginx}: Container started

$ kubectl describe svc web -n ts-cmds
Name:                     web
Namespace:                ts-cmds
Labels:                   app=web
Annotations:              <none>
Selector:                 app=web
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.110.103.117
IPs:                      10.110.103.117
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.0.104:80,10.244.0.105:80
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>

```

## kubectl logs - what did the process print?
```text
$ kubectl logs web-f4c54c7fc-r5d9h -n ts-cmds --tail=5
2026/10/07 15:28:54 [notice] 1#1: start worker process 49
2026/10/07 15:28:54 [notice] 1#1: start worker process 50
2026/10/07 15:28:54 [notice] 1#1: start worker process 51
2026/10/07 15:28:54 [notice] 1#1: start worker process 52
2026/10/07 15:28:54 [notice] 1#1: start worker process 53

$ kubectl logs deploy/web -n ts-cmds --tail=3
Found 2 pods, using pod/web-f4c54c7fc-r5d9h
2026/10/07 15:28:54 [notice] 1#1: start worker process 51
2026/10/07 15:28:54 [notice] 1#1: start worker process 52
2026/10/07 15:28:54 [notice] 1#1: start worker process 53

$ kubectl logs -l app=web -n ts-cmds --tail=2 --prefix
[pod/web-f4c54c7fc-r5d9h/nginx] 2026/10/07 15:28:54 [notice] 1#1: start worker process 52
[pod/web-f4c54c7fc-r5d9h/nginx] 2026/10/07 15:28:54 [notice] 1#1: start worker process 53
[pod/web-f4c54c7fc-xwgdq/nginx] 2026/10/07 15:28:55 [notice] 1#1: start worker process 52
[pod/web-f4c54c7fc-xwgdq/nginx] 2026/10/07 15:28:55 [notice] 1#1: start worker process 53

$ kubectl logs web-f4c54c7fc-r5d9h -n ts-cmds --since=30s --timestamps --tail=3

# --previous shows the logs of the last crashed instance (see the CrashLoopBackOff case)
```

## kubectl exec - look from inside the container
```text
$ kubectl exec web-f4c54c7fc-r5d9h -n ts-cmds -- nginx -v
nginx version: nginx/1.25.5

$ kubectl exec web-f4c54c7fc-r5d9h -n ts-cmds -- cat /etc/resolv.conf
search ts-cmds.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

$ kubectl exec web-f4c54c7fc-r5d9h -n ts-cmds -- env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=web-f4c54c7fc-r5d9h
NGINX_VERSION=1.25.5
PKG_RELEASE=1
NJS_VERSION=0.8.4
NJS_RELEASE=3
WEB_SERVICE_PORT=80
WEB_PORT_80_TCP=tcp://10.110.103.117:80
WEB_PORT_80_TCP_PROTO=tcp
KUBERNETES_SERVICE_PORT=443
WEB_PORT_80_TCP_PORT=80
KUBERNETES_SERVICE_HOST=10.96.0.1
KUBERNETES_PORT=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
KUBERNETES_PORT_443_TCP_PORT=443
WEB_SERVICE_HOST=10.110.103.117
WEB_PORT=tcp://10.110.103.117:80
WEB_PORT_80_TCP_ADDR=10.110.103.117
KUBERNETES_SERVICE_PORT_HTTPS=443
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
KUBERNETES_PORT_443_TCP_PROTO=tcp
HOME=/root

$ kubectl exec web-f4c54c7fc-r5d9h -n ts-cmds -- netstat -tln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      
tcp        0      0 :::80                   :::*                    LISTEN      

$ kubectl exec web-f4c54c7fc-r5d9h -n ts-cmds -- sh -c 'ps aux; df -h /'
PID   USER     TIME  COMMAND
    1 root      0:00 nginx: master process nginx -g daemon off;
   30 nginx     0:00 nginx: worker process
   31 nginx     0:00 nginx: worker process
   32 nginx     0:00 nginx: worker process
   33 nginx     0:00 nginx: worker process
   34 nginx     0:00 nginx: worker process
   35 nginx     0:00 nginx: worker process
   36 nginx     0:00 nginx: worker process
   37 nginx     0:00 nginx: worker process
   38 nginx     0:00 nginx: worker process
   39 nginx     0:00 nginx: worker process
   40 nginx     0:00 nginx: worker process
   41 nginx     0:00 nginx: worker process
   42 nginx     0:00 nginx: worker process
   43 nginx     0:00 nginx: worker process
   44 nginx     0:00 nginx: worker process
   45 nginx     0:00 nginx: worker process
   46 nginx     0:00 nginx: worker process
   47 nginx     0:00 nginx: worker process
   48 nginx     0:00 nginx: worker process
   49 nginx     0:00 nginx: worker process
   50 nginx     0:00 nginx: worker process
   51 nginx     0:00 nginx: worker process
   52 nginx     0:00 nginx: worker process
   53 nginx     0:00 nginx: worker process
   78 root      0:00 sh -c ps aux; df -h /
   84 root      0:00 ps aux
Filesystem                Size      Used Available Use% Mounted on
overlay                1006.9G      9.9G    945.7G   1% /

$ kubectl exec client -n ts-cmds -- nslookup web
Server:		10.96.0.10
Address:	10.96.0.10:53

** server can't find web.cluster.local: NXDOMAIN

** server can't find web.svc.cluster.local: NXDOMAIN

** server can't find web.cluster.local: NXDOMAIN

Name:	web.ts-cmds.svc.cluster.local
Address: 10.110.103.117


** server can't find web.svc.cluster.local: NXDOMAIN

command terminated with exit code 1

```

## kubectl events - the cluster's own timeline
```text
$ kubectl events -n ts-cmds | tail -15
50s         Normal   ScalingReplicaSet   Deployment/web              Scaled up replica set web-f4c54c7fc from 1 to 2
50s         Normal   Pulled              Pod/web-f4c54c7fc-r5d9h     Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
50s         Normal   Created             Pod/web-f4c54c7fc-r5d9h     Container created
50s         Normal   Started             Pod/web-f4c54c7fc-r5d9h     Container started
50s         Normal   Scheduled           Pod/web-f4c54c7fc-xwgdq     Successfully assigned ts-cmds/web-f4c54c7fc-xwgdq to minikube
49s         Normal   Killing             Pod/web-68847bc8d4-cm5pf    Stopping container nginx
49s         Normal   Created             Pod/web-f4c54c7fc-xwgdq     Container created
49s         Normal   Started             Pod/web-f4c54c7fc-xwgdq     Container started
49s         Normal   SuccessfulDelete    ReplicaSet/web-68847bc8d4   Deleted pod: web-68847bc8d4-wtr8z
49s         Normal   Killing             Pod/web-68847bc8d4-wtr8z    Stopping container nginx
49s         Normal   Scheduled           Pod/client                  Successfully assigned ts-cmds/client to minikube
49s         Normal   Started             Pod/client                  Container started
49s         Normal   Created             Pod/client                  Container created
49s         Normal   Pulled              Pod/client                  Container image "busybox:1.36" already present on machine and can be accessed by the pod
49s         Normal   ScalingReplicaSet   Deployment/web              Scaled down replica set web-68847bc8d4 from 1 to 0

$ kubectl events -n ts-cmds --for pod/web-f4c54c7fc-r5d9h
LAST SEEN   TYPE     REASON      OBJECT                    MESSAGE
52s         Normal   Scheduled   Pod/web-f4c54c7fc-r5d9h   Successfully assigned ts-cmds/web-f4c54c7fc-r5d9h to minikube
50s         Normal   Pulled      Pod/web-f4c54c7fc-r5d9h   Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
50s         Normal   Created     Pod/web-f4c54c7fc-r5d9h   Container created
50s         Normal   Started     Pod/web-f4c54c7fc-r5d9h   Container started

$ kubectl events -A --types=Warning | tail -10
default         4m47s                   Warning   ProvisioningFailed   PersistentVolumeClaim/pvc-demo                 storageclass.storage.k8s.io "manual" not found
default         4m33s (x3 over 4m47s)   Warning   FailedScheduling     Pod/pvc-consumer                               0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. not found
default         3m26s (x2 over 3m26s)   Warning   FailedScheduling     Pod/dynamic-consumer                           0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. not found
default         86s (x12 over 3m11s)    Warning   Unhealthy            Pod/failing-liveness                           Liveness probe failed: HTTP probe failed with statuscode: 404
default         85s (x4 over 2m20s)     Warning   BackOff              Pod/failing-liveness                           Back-off restarting failed container web in pod failing-liveness_default(88dda37c-99cd-47fb-a32b-d6cd3723e63f)
default         84s (x2 over 89s)       Warning   Unhealthy            Pod/probe-handlers                             Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
default         62s                     Warning   Unhealthy            Pod/probes-demo-57cdc94dff-448kt               Readiness probe failed: Get "http://10.244.0.97:80/": dial tcp 10.244.0.97:80: connect: connection refused
default         62s                     Warning   Unhealthy            Pod/probes-demo-57cdc94dff-tv57t               Readiness probe failed: Get "http://10.244.0.96:80/": dial tcp 10.244.0.96:80: connect: connection refused
default         62s (x20 over 2m29s)    Warning   Unhealthy            Pod/failing-readiness                          Readiness probe failed: HTTP probe failed with statuscode: 404
default         28s (x6 over 53s)       Warning   Unhealthy            Pod/probe-handlers                             Readiness probe failed: dial tcp 10.244.0.101:80: connect: connection refused

$ kubectl get events -n ts-cmds --sort-by=.lastTimestamp | tail -8
49s         Normal   Started             pod/web-f4c54c7fc-xwgdq     Container started
49s         Normal   SuccessfulDelete    replicaset/web-68847bc8d4   Deleted pod: web-68847bc8d4-wtr8z
49s         Normal   Killing             pod/web-68847bc8d4-wtr8z    Stopping container nginx
49s         Normal   Scheduled           pod/client                  Successfully assigned ts-cmds/client to minikube
49s         Normal   Started             pod/client                  Container started
49s         Normal   Created             pod/client                  Container created
49s         Normal   Pulled              pod/client                  Container image "busybox:1.36" already present on machine and can be accessed by the pod
49s         Normal   ScalingReplicaSet   deployment/web              Scaled down replica set web-68847bc8d4 from 1 to 0

```

## kubectl explain - built-in API documentation
```text
$ kubectl explain pod.spec.containers.readinessProbe
KIND:       Pod
VERSION:    v1

FIELD: readinessProbe <Probe>


DESCRIPTION:
    Periodic probe of container service readiness. Container will be removed
    from service endpoints if the probe fails. Cannot be updated. More info:
    https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes
    Probe describes a health check to be performed against a container to
    determine whether it is alive or ready to receive traffic.
    
FIELDS:
  exec	<ExecAction>
    Exec specifies a command to execute in the container.

  failureThreshold	<integer>
    Minimum consecutive failures for the probe to be considered failed after
    having succeeded. Defaults to 3. Minimum value is 1.

  grpc	<GRPCAction>
    GRPC specifies a GRPC HealthCheckRequest.

  httpGet	<HTTPGetAction>
    HTTPGet specifies an HTTP GET request to perform.

  initialDelaySeconds	<integer>
    Number of seconds after the container has started before liveness probes are
    initiated. More info:
    https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes

  periodSeconds	<integer>
    How often (in seconds) to perform the probe. Default to 10 seconds. Minimum
    value is 1.

  successThreshold	<integer>
    Minimum consecutive successes for the probe to be considered successful
    after having failed. Defaults to 1. Must be 1 for liveness and startup.
    Minimum value is 1.

  tcpSocket	<TCPSocketAction>
    TCPSocket specifies a connection to a TCP port.

  terminationGracePeriodSeconds	<integer>
    Optional duration in seconds the pod needs to terminate gracefully upon
    probe failure. The grace period is the duration in seconds after the
    processes running in the pod are sent a termination signal and the time when
    the processes are forcibly halted with a kill signal. Set this value longer
    than the expected cleanup time for your process. If this value is nil, the
    pod's terminationGracePeriodSeconds will be used. Otherwise, this value
    overrides the value provided by the pod spec. Value must be non-negative
    integer. The value zero indicates stop immediately via the kill signal (no
    opportunity to shut down). This is a beta field and requires enabling
    ProbeTerminationGracePeriod feature gate. Minimum value is 1.
    spec.terminationGracePeriodSeconds is used if unset.

  timeoutSeconds	<integer>
    Number of seconds after which the probe times out. Defaults to 1 second.
    Minimum value is 1. More info:
    https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle#container-probes



$ kubectl explain deployment.spec.strategy.rollingUpdate
GROUP:      apps
KIND:       Deployment
VERSION:    v1

FIELD: rollingUpdate <RollingUpdateDeployment>


DESCRIPTION:
    Rolling update config params. Present only if DeploymentStrategyType =
    RollingUpdate.
    Spec to control the desired behavior of rolling update.
    
FIELDS:
  maxSurge	<IntOrString>
    The maximum number of pods that can be scheduled above the desired number of
    pods. Value can be an absolute number (ex: 5) or a percentage of desired
    pods (ex: 10%). This can not be 0 if MaxUnavailable is 0. Absolute number is
    calculated from percentage by rounding up. Defaults to 25%. Example: when
    this is set to 30%, the new ReplicaSet can be scaled up immediately when the
    rolling update starts, such that the total number of old and new pods do not
    exceed 130% of desired pods. Once old pods have been killed, new ReplicaSet
    can be scaled up further, ensuring that total number of pods running at any
    time during the update is at most 130% of desired pods.

  maxUnavailable	<IntOrString>
    The maximum number of pods that can be unavailable during the update. Value
    can be an absolute number (ex: 5) or a percentage of desired pods (ex: 10%).
    Absolute number is calculated from percentage by rounding down. This can not
    be 0 if MaxSurge is 0. Defaults to 25%. Example: when this is set to 30%,
    the old ReplicaSet can be scaled down to 70% of desired pods immediately
    when the rolling update starts. Once new pods are ready, old ReplicaSet can
    be scaled down further, followed by scaling up the new ReplicaSet, ensuring
    that the total number of pods available at all times during the update is at
    least 70% of desired pods.



$ kubectl explain pod.spec --recursive | head -30
KIND:       Pod
VERSION:    v1

FIELD: spec <PodSpec>


DESCRIPTION:
    Specification of the desired behavior of the pod. More info:
    https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#spec-and-status
    PodSpec is a description of a pod.
    
FIELDS:
  activeDeadlineSeconds	<integer>
  affinity	<Affinity>
    nodeAffinity	<NodeAffinity>
      preferredDuringSchedulingIgnoredDuringExecution	<[]PreferredSchedulingTerm>
        preference	<NodeSelectorTerm> -required-
          matchExpressions	<[]NodeSelectorRequirement>
            key	<string> -required-
            operator	<string> -required-
            enum: DoesNotExist, Exists, Gt, In, ....
            values	<[]string>
          matchFields	<[]NodeSelectorRequirement>
            key	<string> -required-
            operator	<string> -required-
            enum: DoesNotExist, Exists, Gt, In, ....
            values	<[]string>
        weight	<integer> -required-
      requiredDuringSchedulingIgnoredDuringExecution	<NodeSelector>
        nodeSelectorTerms	<[]NodeSelectorTerm> -required-

```

## kubectl top - live CPU and memory (needs metrics-server)
```text
$ kubectl top nodes
NAME       CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
minikube   245m         1%       1828Mi          23%         

$ kubectl top pods -n ts-cmds
NAME                  CPU(cores)   MEMORY(bytes)   
web-f4c54c7fc-2gxfk   0m           17Mi            
web-f4c54c7fc-2hwp2   2m           17Mi            

$ kubectl top pods -n ts-cmds --containers
POD                   NAME    CPU(cores)   MEMORY(bytes)   
web-f4c54c7fc-2gxfk   nginx   0m           17Mi            
web-f4c54c7fc-2hwp2   nginx   2m           17Mi            

$ kubectl top pods -A --sort-by=cpu | head -10
NAMESPACE       NAME                                       CPU(cores)   MEMORY(bytes)   
kube-system     kube-apiserver-minikube                    51m          294Mi           
kube-system     etcd-minikube                              30m          66Mi            
kube-system     kube-controller-manager-minikube           18m          63Mi            
kube-system     kube-scheduler-minikube                    8m           31Mi            
kube-system     metrics-server-768f9f6999-gmvx9            4m           27Mi            
ingress-nginx   ingress-nginx-controller-d7cd8c989-tfmp7   4m           274Mi           
kube-system     storage-provisioner                        3m           11Mi            
ts-cmds         web-f4c54c7fc-2hwp2                        2m           17Mi            
kube-system     coredns-559f6c778d-zndtf                   2m           17Mi            

```

## Other everyday helpers
```text
$ kubectl get deploy web -n ts-cmds -o yaml --show-managed-fields=false
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
  creationTimestamp: "2026-10-07T15:28:52Z"
  generation: 2
  labels:
    app: web
  name: web
  namespace: ts-cmds
  resourceVersion: "4714"
  uid: 71a639d0-90db-492a-814b-562c2e38da91
spec:
  progressDeadlineSeconds: 600
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: web
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: nginx:1.25-alpine
        imagePullPolicy: IfNotPresent
        name: nginx
        resources:
          limits:
            cpu: 100m
            memory: 64Mi
          requests:
            cpu: 20m
            memory: 16Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
status:
  availableReplicas: 2
  conditions:
  - lastTransitionTime: "2026-10-07T15:28:53Z"
    lastUpdateTime: "2026-10-07T15:28:53Z"
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: "2026-10-07T15:28:52Z"
    lastUpdateTime: "2026-10-07T15:28:55Z"
    message: ReplicaSet "web-f4c54c7fc" has successfully progressed.
    reason: NewReplicaSetAvailable
    status: "True"
    type: Progressing
  observedGeneration: 2
  readyReplicas: 2
  replicas: 2
  terminatingReplicas: 0
  updatedReplicas: 2

$ kubectl auth can-i list secrets -n ts-cmds --as=system:serviceaccount:ts-cmds:default
no

$ kubectl api-resources --namespaced=true -o name
bindings
configmaps
endpoints
events
limitranges
persistentvolumeclaims
pods
podtemplates
replicationcontrollers
resourcequotas
secrets
serviceaccounts
services
controllerrevisions.apps
daemonsets.apps
deployments.apps
replicasets.apps
statefulsets.apps
localsubjectaccessreviews.authorization.k8s.io
horizontalpodautoscalers.autoscaling
cronjobs.batch
jobs.batch
podcertificaterequests.certificates.k8s.io
leases.coordination.k8s.io
endpointslices.discovery.k8s.io
events.events.k8s.io
pods.metrics.k8s.io
ingresses.networking.k8s.io
networkpolicies.networking.k8s.io
poddisruptionbudgets.policy
rolebindings.rbac.authorization.k8s.io
roles.rbac.authorization.k8s.io
resourceclaims.resource.k8s.io
resourceclaimtemplates.resource.k8s.io
csistoragecapacities.storage.k8s.io

$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:63561
CoreDNS is running at https://127.0.0.1:63561/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

$ kubectl get --raw='/readyz?verbose' | tail -5
[+]autoregister-completion ok
[+]poststarthook/apiservice-openapi-controller ok
[+]poststarthook/apiservice-openapiv3-controller ok
[+]shutdown ok
readyz check passed

```
