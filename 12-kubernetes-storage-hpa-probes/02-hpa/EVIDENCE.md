# Evidence — HPA

Executed on minikube v1.39.0 / Kubernetes v1.37.0, metrics-server v0.9.0, 2026-10-07. Output is verbatim.

Run 1 covers deploy, verify, load and scale-out (its observation window ended before scale-in). Run 2 repeats the load and then watches scale-in to the minimum.

# Run 1 — scale-out

## 1. Deploy the application and 2. configure the HPA
```text
$ kubectl apply -f hpa.yml
deployment.apps/php-apache created
service/php-apache created
horizontalpodautoscaler.autoscaling/php-apache created

$ kubectl rollout status deploy/php-apache --timeout=300s
Waiting for deployment "php-apache" rollout to finish: 0 of 1 updated replicas are available...
deployment "php-apache" successfully rolled out

```

## 3. Verify the HPA
```text
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          95s

$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-nckd6   1m           8Mi             

$ kubectl describe hpa php-apache | sed -n '1,/^Events:/p'
Name:                                                  php-apache
Namespace:                                             default
Labels:                                                <none>
Annotations:                                           <none>
CreationTimestamp:                                     Wed, 07 Oct 2026 21:16:24 +0530
Reference:                                             Deployment/php-apache
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  0% (1m) / 50%
Min replicas:                                          1
Max replicas:                                          10
Behavior:
  Scale Up:
    Stabilization Window: 0 seconds
    Select Policy: Max
    Policies:
      - Type: Percent  Value: 100  Period: 15 seconds
  Scale Down:
    Stabilization Window: 300 seconds
    Select Policy: Max
    Policies:
      - Type: Percent  Value: 50  Period: 60 seconds
Deployment pods:       1 current / 1 desired
Conditions:
  Type            Status  Reason               Message
  ----            ------  ------               -------
  AbleToScale     True    ScaleDownStabilized  recent recommendations were higher than current one, applying the highest recent recommendation
  ScalingActive   True    ValidMetricFound     the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  False   DesiredWithinRange   the desired count is within the acceptable range
Events:

```

## 4. Deploy the load generator / 5. increase load
```text
$ kubectl apply -f load-generator.yaml
deployment.apps/load-generator created

$ kubectl rollout status deploy/load-generator --timeout=180s
Waiting for deployment "load-generator" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "load-generator" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "load-generator" rollout to finish: 2 of 3 updated replicas are available...
deployment "load-generator" successfully rolled out

```

## 6. CPU utilisation and 7. Pod scaling, sampled every 30s
```text
----- t+0s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          97s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-nckd6   1m           8Mi             
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   1/1     1            1           98s

----- t+30s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          2m8s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-nckd6   1m           8Mi             
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   1/1     1            1           2m8s

----- t+60s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 165%/50%   1         10        1          2m39s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-nckd6   331m         15Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   2/2     2            2           2m39s

----- t+90s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 165%/50%   1         10        4          3m9s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-nckd6   331m         15Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   4/4     4            4           3m10s

----- t+120s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 150%/50%   1         10        4          3m40s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-7vpmv   267m         12Mi            
php-apache-5899f79df5-9ftwd   278m         14Mi            
php-apache-5899f79df5-n58mw   279m         14Mi            
php-apache-5899f79df5-nckd6   354m         15Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   8/8     8            8           3m41s

----- t+150s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 150%/50%   1         10        9          4m11s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-7vpmv   267m         12Mi            
php-apache-5899f79df5-9ftwd   278m         14Mi            
php-apache-5899f79df5-n58mw   279m         14Mi            
php-apache-5899f79df5-nckd6   354m         15Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   9/9     9            9           4m12s

----- t+180s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 76%/50%   1         10        9          4m42s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-5fmzr   135m         13Mi            
php-apache-5899f79df5-7vpmv   190m         12Mi            
php-apache-5899f79df5-9ftwd   207m         14Mi            
php-apache-5899f79df5-9llxk   137m         14Mi            
php-apache-5899f79df5-cxpm7   134m         13Mi            
php-apache-5899f79df5-n58mw   163m         14Mi            
php-apache-5899f79df5-nckd6   124m         15Mi            
php-apache-5899f79df5-sz94z   131m         14Mi            
php-apache-5899f79df5-wjv2c   123m         11Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   10/10   10           10          4m43s

----- t+210s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 76%/50%   1         10        10         5m13s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-5fmzr   135m         13Mi            
php-apache-5899f79df5-7vpmv   190m         12Mi            
php-apache-5899f79df5-9ftwd   207m         14Mi            
php-apache-5899f79df5-9llxk   137m         14Mi            
php-apache-5899f79df5-cxpm7   134m         13Mi            
php-apache-5899f79df5-n58mw   163m         14Mi            
php-apache-5899f79df5-nckd6   124m         15Mi            
php-apache-5899f79df5-sz94z   131m         14Mi            
php-apache-5899f79df5-wjv2c   123m         11Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   10/10   10           10          5m13s

----- t+240s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 64%/50%   1         10        10         5m44s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-5fmzr   153m         12Mi            
php-apache-5899f79df5-7vpmv   128m         13Mi            
php-apache-5899f79df5-9ftwd   116m         13Mi            
php-apache-5899f79df5-9llxk   132m         13Mi            
php-apache-5899f79df5-cxpm7   119m         13Mi            
php-apache-5899f79df5-jhc9k   125m         12Mi            
php-apache-5899f79df5-n58mw   137m         14Mi            
php-apache-5899f79df5-nckd6   127m         14Mi            
php-apache-5899f79df5-sz94z   127m         14Mi            
php-apache-5899f79df5-wjv2c   130m         12Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   10/10   10           10          5m44s

----- t+270s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 64%/50%   1         10        10         6m14s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-5fmzr   153m         12Mi            
php-apache-5899f79df5-7vpmv   128m         13Mi            
php-apache-5899f79df5-9ftwd   116m         13Mi            
php-apache-5899f79df5-9llxk   132m         13Mi            
php-apache-5899f79df5-cxpm7   119m         13Mi            
php-apache-5899f79df5-jhc9k   125m         12Mi            
php-apache-5899f79df5-n58mw   137m         14Mi            
php-apache-5899f79df5-nckd6   127m         14Mi            
php-apache-5899f79df5-sz94z   127m         14Mi            
php-apache-5899f79df5-wjv2c   130m         12Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   10/10   10           10          6m15s

----- t+300s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 58%/50%   1         10        10         6m45s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-5fmzr   120m         13Mi            
php-apache-5899f79df5-7vpmv   111m         13Mi            
php-apache-5899f79df5-9ftwd   110m         14Mi            
php-apache-5899f79df5-9llxk   129m         13Mi            
php-apache-5899f79df5-cxpm7   104m         12Mi            
php-apache-5899f79df5-jhc9k   123m         12Mi            
php-apache-5899f79df5-n58mw   94m          14Mi            
php-apache-5899f79df5-nckd6   116m         15Mi            
php-apache-5899f79df5-sz94z   124m         14Mi            
php-apache-5899f79df5-wjv2c   147m         13Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   10/10   10           10          6m45s

----- t+330s -----
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 58%/50%   1         10        10         7m16s
$ kubectl top pods -l run=php-apache
NAME                          CPU(cores)   MEMORY(bytes)   
php-apache-5899f79df5-5fmzr   120m         13Mi            
php-apache-5899f79df5-7vpmv   111m         13Mi            
php-apache-5899f79df5-9ftwd   110m         14Mi            
php-apache-5899f79df5-9llxk   129m         13Mi            
php-apache-5899f79df5-cxpm7   104m         12Mi            
php-apache-5899f79df5-jhc9k   123m         12Mi            
php-apache-5899f79df5-n58mw   94m          14Mi            
php-apache-5899f79df5-nckd6   116m         15Mi            
php-apache-5899f79df5-sz94z   124m         14Mi            
php-apache-5899f79df5-wjv2c   147m         13Mi            
$ kubectl get deploy php-apache
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   10/10   10           10          7m16s

```

## Scale-out evidence
```text
$ kubectl get pods -l run=php-apache -o wide
NAME                          READY   STATUS    RESTARTS   AGE     IP             NODE       NOMINATED NODE   READINESS GATES
php-apache-5899f79df5-5fmzr   1/1     Running   0          4m15s   10.244.0.190   minikube   <none>           <none>
php-apache-5899f79df5-7vpmv   1/1     Running   0          5m1s    10.244.0.185   minikube   <none>           <none>
php-apache-5899f79df5-9ftwd   1/1     Running   0          5m16s   10.244.0.183   minikube   <none>           <none>
php-apache-5899f79df5-9llxk   1/1     Running   0          4m15s   10.244.0.188   minikube   <none>           <none>
php-apache-5899f79df5-cxpm7   1/1     Running   0          4m      10.244.0.193   minikube   <none>           <none>
php-apache-5899f79df5-jhc9k   1/1     Running   0          3m15s   10.244.0.199   minikube   <none>           <none>
php-apache-5899f79df5-n58mw   1/1     Running   0          5m1s    10.244.0.184   minikube   <none>           <none>
php-apache-5899f79df5-nckd6   1/1     Running   0          7m46s   10.244.0.168   minikube   <none>           <none>
php-apache-5899f79df5-sz94z   1/1     Running   0          4m15s   10.244.0.187   minikube   <none>           <none>
php-apache-5899f79df5-wjv2c   1/1     Running   0          4m15s   10.244.0.189   minikube   <none>           <none>

$ kubectl describe hpa php-apache | sed -n '/^Events:/,$p'
Events:
  Type     Reason                        Age                    From                       Message
  ----     ------                        ----                   ----                       -------
  Warning  FailedGetResourceMetric       7m32s (x2 over 7m47s)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedComputeMetricsReplicas  7m32s (x2 over 7m47s)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       6m32s (x4 over 7m17s)  horizontal-pod-autoscaler  failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)
  Warning  FailedComputeMetricsReplicas  6m32s (x4 over 7m17s)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)
  Normal   SuccessfulRescale             5m17s                  horizontal-pod-autoscaler  New size: 2; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             5m2s                   horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             4m16s                  horizontal-pod-autoscaler  New size: 8; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             4m1s                   horizontal-pod-autoscaler  New size: 9; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             3m16s                  horizontal-pod-autoscaler  New size: 10; reason: cpu resource utilization (percentage of request) above target

```

## Remove the load and watch it scale back in
```text
$ kubectl delete -f load-generator.yaml
deployment.apps "load-generator" deleted from default namespace

# scaleDown.stabilizationWindowSeconds is 300s, so nothing happens for 5 minutes
----- t+0s after load removed -----
php-apache   Deployment/php-apache   cpu: 70%/50%   1     10    10    7m47s
----- t+30s after load removed -----
php-apache   Deployment/php-apache   cpu: 70%/50%   1     10    10    8m18s
----- t+60s after load removed -----
php-apache   Deployment/php-apache   cpu: 72%/50%   1     10    10    8m48s
----- t+90s after load removed -----
php-apache   Deployment/php-apache   cpu: 72%/50%   1     10    10    9m18s
----- t+120s after load removed -----
php-apache   Deployment/php-apache   cpu: 3%/50%   1     10    10    9m48s
----- t+150s after load removed -----
php-apache   Deployment/php-apache   cpu: 3%/50%   1     10    10    10m
----- t+180s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    10m
----- t+210s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    11m
----- t+240s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    11m
----- t+270s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    12m
----- t+300s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    12m
----- t+330s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    13m
----- t+360s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    13m
----- t+390s after load removed -----
php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    14m

$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        5          14m

$ kubectl describe hpa php-apache | sed -n '/^Events:/,$p'
Events:
  Type     Reason                        Age                From                       Message
  ----     ------                        ----               ----                       -------
  Warning  FailedGetResourceMetric       14m (x2 over 14m)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedComputeMetricsReplicas  14m (x2 over 14m)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       13m (x4 over 14m)  horizontal-pod-autoscaler  failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)
  Warning  FailedComputeMetricsReplicas  13m (x4 over 14m)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: did not receive metrics for targeted pods (pods might be unready)
  Normal   SuccessfulRescale             12m                horizontal-pod-autoscaler  New size: 2; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             12m                horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             11m                horizontal-pod-autoscaler  New size: 8; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             11m                horizontal-pod-autoscaler  New size: 9; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             10m                horizontal-pod-autoscaler  New size: 10; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             34s                horizontal-pod-autoscaler  New size: 5; reason: All metrics below target

```

# Run 2 — scale-in

## Scale-in: the HPA waits out its 300s stabilization window
```text
$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 143%/50%   1         10        6          114s

$ kubectl delete -f load-generator.yaml
deployment.apps "load-generator" deleted from default namespace

t+   0s  php-apache   Deployment/php-apache   cpu: 143%/50%   1     10    6     115s
t+  31s  php-apache   Deployment/php-apache   cpu: 143%/50%   1     10    6     2m25s
t+  62s  php-apache   Deployment/php-apache   cpu: 98%/50%   1     10    10    2m56s
t+  92s  php-apache   Deployment/php-apache   cpu: 98%/50%   1     10    10    3m26s
t+ 123s  php-apache   Deployment/php-apache   cpu: 19%/50%   1     10    10    3m57s
t+ 153s  php-apache   Deployment/php-apache   cpu: 19%/50%   1     10    10    4m28s
t+ 184s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    4m58s
t+ 214s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    5m29s
t+ 245s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    5m59s
t+ 275s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    6m29s
t+ 306s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    7m
t+ 336s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    7m30s
t+ 366s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    8m
t+ 396s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    10    8m30s
t+ 427s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    5     9m1s
t+ 457s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    2     9m31s
t+ 487s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    2     10m
t+ 518s  php-apache   Deployment/php-apache   cpu: 0%/50%   1     10    1     10m

$ kubectl get hpa php-apache
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 0%/50%   1         10        1          10m

$ kubectl describe hpa php-apache | sed -n '/^Events:/,$p'
Events:
  Type     Reason                        Age                From                       Message
  ----     ------                        ----               ----                       -------
  Warning  FailedGetResourceMetric       10m (x2 over 10m)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedComputeMetricsReplicas  10m (x2 over 10m)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Normal   SuccessfulRescale             10m                horizontal-pod-autoscaler  New size: 2; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             9m47s              horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             9m32s              horizontal-pod-autoscaler  New size: 5; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             9m2s               horizontal-pod-autoscaler  New size: 6; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             8m2s               horizontal-pod-autoscaler  New size: 10; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             2m16s              horizontal-pod-autoscaler  New size: 5; reason: All metrics below target
  Normal   SuccessfulRescale             76s                horizontal-pod-autoscaler  New size: 2; reason: All metrics below target
  Normal   SuccessfulRescale             16s                horizontal-pod-autoscaler  New size: 1; reason: All metrics below target

```
