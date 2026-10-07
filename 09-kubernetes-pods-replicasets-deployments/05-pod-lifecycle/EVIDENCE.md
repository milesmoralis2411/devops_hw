# Evidence — Pod Lifecycle

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd 2.3.4), 2026-10-07. Output is verbatim.

## 01 - Pending
```text
$ kubectl apply -f 01-pending.yaml
pod/lifecycle-pending created

$ kubectl get pod lifecycle-pending -o wide
NAME                READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE   READINESS GATES
lifecycle-pending   0/1     Pending   0          8s    <none>   <none>   <none>           <none>

$ kubectl describe pod lifecycle-pending | sed -n '/^Status:/p;/^Conditions:/,/^Volumes:/p;/^Events:/,$p'
Status:           Pending
Conditions:
  Type           Status
  PodScheduled   False 
Volumes:
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  8s    default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

```

## 02 - Running
```text
$ kubectl apply -f 02-running.yaml
pod/lifecycle-running created

$ kubectl wait --for=condition=Ready pod/lifecycle-running --timeout=120s
pod/lifecycle-running condition met

$ kubectl get pod lifecycle-running -o wide
NAME                READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
lifecycle-running   1/1     Running   0          1s    10.244.0.75   minikube   <none>           <none>

$ kubectl get pod lifecycle-running -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
PodReadyToStartContainers=True
Initialized=True
Ready=True
ContainersReady=True
PodScheduled=True

$ kubectl describe pod lifecycle-running | sed -n '/^Events:/,$p'
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  2s    default-scheduler  Successfully assigned default/lifecycle-running to minikube
  Normal  Pulled     1s    kubelet            spec.containers{app}: Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
  Normal  Created    1s    kubelet            spec.containers{app}: Container created
  Normal  Started    1s    kubelet            spec.containers{app}: Container started

```

## 03 - Succeeded
```text
$ kubectl apply -f 03-succeeded.yaml
pod/lifecycle-succeeded created

$ kubectl get pod lifecycle-succeeded
NAME                  READY   STATUS      RESTARTS   AGE
lifecycle-succeeded   0/1     Completed   0          15s

$ kubectl logs lifecycle-succeeded
doing work
done

$ kubectl get pod lifecycle-succeeded -o jsonpath='phase={.status.phase} exitCode={.status.containerStatuses[0].state.terminated.exitCode} reason={.status.containerStatuses[0].state.terminated.reason}'; echo
phase=Succeeded exitCode=0 reason=Completed

```

## 04 - Failed
```text
$ kubectl apply -f 04-failed.yaml
pod/lifecycle-failed created

$ kubectl get pod lifecycle-failed
NAME               READY   STATUS   RESTARTS   AGE
lifecycle-failed   0/1     Error    0          12s

$ kubectl logs lifecycle-failed
about to fail

$ kubectl get pod lifecycle-failed -o jsonpath='phase={.status.phase} exitCode={.status.containerStatuses[0].state.terminated.exitCode} reason={.status.containerStatuses[0].state.terminated.reason}'; echo
phase=Failed exitCode=1 reason=Error

```

## 05 - CrashLoopBackOff
```text
$ kubectl apply -f 05-crashloopbackoff.yaml
pod/lifecycle-crashloop created

# sample the Pod every 10s: STATUS alternates as the kubelet restarts it with growing back-off
t+  0s  lifecycle-crashloop   0/1   ContainerCreating   0     0s
t+ 10s  lifecycle-crashloop   0/1   Error   1 (6s ago)   10s
t+ 20s  lifecycle-crashloop   0/1   Error   1 (17s ago)   21s
t+ 30s  lifecycle-crashloop   0/1   Error   2 (23s ago)   31s
t+ 40s  lifecycle-crashloop   0/1   Error   2 (33s ago)   41s
t+ 50s  lifecycle-crashloop   0/1   Error   2 (43s ago)   51s
t+ 60s  lifecycle-crashloop   0/1   Error   3 (37s ago)   61s
t+ 70s  lifecycle-crashloop   0/1   Error   3 (47s ago)   71s
t+ 80s  lifecycle-crashloop   0/1   Error   3 (58s ago)   82s

$ kubectl get pod lifecycle-crashloop -o jsonpath='phase={.status.phase} restarts={.status.containerStatuses[0].restartCount} state={.status.containerStatuses[0].state}'; echo
phase=Running restarts=3 state={"terminated":{"containerID":"containerd://5aa327d0dee239ef4ae2bbf0cf48f4955628dc0b744a34dcc71ead064fc7a35e","exitCode":1,"finishedAt":"2026-10-07T15:22:55Z","reason":"Error","startedAt":"2026-10-07T15:22:52Z"}}

$ kubectl describe pod lifecycle-crashloop | sed -n '/^Events:/,$p'
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  92s                default-scheduler  Successfully assigned default/lifecycle-crashloop to minikube
  Normal   Pulled     41s (x4 over 92s)  kubelet            spec.containers{worker}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
  Normal   Created    41s (x4 over 92s)  kubelet            spec.containers{worker}: Container created
  Normal   Started    41s (x4 over 91s)  kubelet            spec.containers{worker}: Container started
  Warning  BackOff    37s (x3 over 83s)  kubelet            spec.containers{worker}: Back-off restarting failed container worker in pod lifecycle-crashloop_default(bfd39b6b-93ac-4f35-9d4d-05882b5d75c7)

# logs of the most recent (crashed) run
$ kubectl logs lifecycle-crashloop
starting

```

## 06 - Init containers
```text
$ kubectl apply -f 06-init-containers.yaml
pod/lifecycle-init created

$ kubectl get pod lifecycle-init   # t+0s
lifecycle-init   0/1   Init:0/2   0     0s
$ kubectl get pod lifecycle-init   # t+5s
lifecycle-init   0/1   Init:0/2   0     6s
$ kubectl get pod lifecycle-init   # t+10s
lifecycle-init   0/1   Init:0/2   0     11s
$ kubectl get pod lifecycle-init   # t+15s
lifecycle-init   0/1   Init:0/2   0     16s
$ kubectl get pod lifecycle-init   # t+20s
lifecycle-init   1/1   Running   0     21s
$ kubectl get pod lifecycle-init   # t+25s
lifecycle-init   1/1   Running   0     26s
$ kubectl get pod lifecycle-init   # t+30s
lifecycle-init   1/1   Running   0     31s

$ kubectl wait --for=condition=Ready pod/lifecycle-init --timeout=120s
pod/lifecycle-init condition met

$ kubectl logs lifecycle-init -c init-wait
init 1: waiting for dependency
init 1 done

$ kubectl logs lifecycle-init -c init-seed
init 2 done

$ kubectl exec lifecycle-init -c app -- cat /usr/share/nginx/html/index.html
<h1>seeded by init container</h1>

$ kubectl get pod lifecycle-init -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: {.state.terminated.reason} (exit {.state.terminated.exitCode}){"\n"}{end}'
init-wait: Completed (exit 0)
init-seed: Completed (exit 0)

```

## 07 - Lifecycle hooks
```text
$ kubectl apply -f 07-lifecycle-hooks.yaml
pod/lifecycle-hooks created

$ kubectl wait --for=condition=Ready pod/lifecycle-hooks --timeout=120s
pod/lifecycle-hooks condition met

$ kubectl exec lifecycle-hooks -- cat /usr/share/nginx/html/hook.txt
postStart hook ran at Wed Oct  7 15:15:38 UTC 2026

$ time kubectl delete pod lifecycle-hooks   # preStop sleeps 10s before nginx quits
pod "lifecycle-hooks" deleted from default namespace
deletion took 11s

```

## 08 - Probes
```text
$ kubectl apply -f 08-probes.yaml
pod/lifecycle-probes created

$ kubectl wait --for=condition=Ready pod/lifecycle-probes --timeout=120s
pod/lifecycle-probes condition met

$ kubectl get pod lifecycle-probes
NAME               READY   STATUS    RESTARTS   AGE
lifecycle-probes   1/1     Running   0          2s

$ kubectl describe pod lifecycle-probes | grep -E '^\s+(Liveness|Readiness|Startup):'
    Liveness:       http-get http://:80/ delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:      http-get http://:80/ delay=2s timeout=1s period=5s #success=1 #failure=3
    Startup:        http-get http://:80/ delay=0s timeout=1s period=2s #success=1 #failure=30

$ kubectl get pod lifecycle-probes -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
PodReadyToStartContainers=True
Initialized=True
Ready=True
ContainersReady=True
PodScheduled=True

```

## Summary of every phase
```text
$ kubectl get pods -l demo=pod-lifecycle -o 'custom-columns=POD:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,STATE:.status.containerStatuses[*].state'
POD                   PHASE       READY    RESTARTS   STATE
lifecycle-crashloop   Running     false    5          map[terminated:map[containerID:containerd://ad3a2d11f597815d7910d39c62befd8f02ad549b9d362cf78d46e8de1ff7da1b exitCode:1 finishedAt:2026-10-07T15:15:36Z reason:Error startedAt:2026-10-07T15:15:33Z]]
lifecycle-failed      Failed      false    0          map[terminated:map[containerID:containerd://da83ed309fc4d0ff11286f8e6351fbfad68b6d4e8042b34b3d72776a52318bdc exitCode:1 finishedAt:2026-10-07T15:12:30Z reason:Error startedAt:2026-10-07T15:12:27Z]]
lifecycle-init        Running     true     0          map[running:map[startedAt:2026-10-07T15:15:17Z]]
lifecycle-pending     Pending     <none>   <none>     <none>
lifecycle-probes      Running     true     0          map[running:map[startedAt:2026-10-07T15:15:50Z]]
lifecycle-running     Running     true     0          map[running:map[startedAt:2026-10-07T15:12:10Z]]
lifecycle-succeeded   Succeeded   false    0          map[terminated:map[containerID:containerd://75eecc935f14fe1323e32c6154d401e929490d49544c0f0825bf54cd37e8eabc exitCode:0 finishedAt:2026-10-07T15:12:16Z reason:Completed startedAt:2026-10-07T15:12:11Z]]

$ kubectl get pods -l demo=pod-lifecycle
NAME                  READY   STATUS      RESTARTS       AGE
lifecycle-crashloop   0/1     Error       5 (101s ago)   3m14s
lifecycle-failed      0/1     Error       0              3m27s
lifecycle-init        1/1     Running     0              53s
lifecycle-pending     0/1     Pending     0              3m52s
lifecycle-probes      1/1     Running     0              3s
lifecycle-running     1/1     Running     0              3m44s
lifecycle-succeeded   0/1     Completed   0              3m42s

```
