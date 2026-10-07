# Evidence — Helm mini project

Executed with Helm v3.22.0 on minikube v1.39.0 / Kubernetes v1.37.0, 2026-10-07. Output is verbatim.

## One chart, two environments
```text
$ helm lint yatri-app -f values-dev.yaml
==> Linting yatri-app
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm lint yatri-app -f values-prod.yaml
==> Linting yatri-app
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm install yatri-app ./yatri-app -n dev --create-namespace -f values-dev.yaml --wait --timeout 3m
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:55:29 2026
NAMESPACE: dev
STATUS: deployed
REVISION: 1
NOTES:
Release "yatri-app" is now revision 1.

  Chart:       yatri-app-0.1.0
  App version: 1.25-alpine
  Namespace:   dev
  Replicas:    1

Reach the application:
  kubectl port-forward -n dev svc/yatri-app 8080:80
  curl http://localhost:8080

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

$ helm install yatri-app ./yatri-app -n prod --create-namespace -f values-prod.yaml --wait --timeout 3m
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:55:37 2026
NAMESPACE: prod
STATUS: deployed
REVISION: 1
NOTES:
Release "yatri-app" is now revision 1.

  Chart:       yatri-app-0.1.0
  App version: 1.26-alpine
  Namespace:   prod
  Replicas:    3-10 (HPA)

Reach the application:
  http://yatri-prod.local/

  Add the host to /etc/hosts first:
    echo "$(minikube ip)  yatri-prod.local" | sudo tee -a /etc/hosts

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

$ helm list -A
NAME     	NAMESPACE	REVISION	UPDATED                              	STATUS  	CHART          	APP VERSION
yatri-app	dev      	1       	2026-10-07 21:55:29.1416766 +0530 IST	deployed	yatri-app-0.1.0	1.25-alpine
yatri-app	prod     	1       	2026-10-07 21:55:37.5809459 +0530 IST	deployed	yatri-app-0.1.0	1.25-alpine

```

## What each environment got
```text
$ kubectl get deploy,svc,hpa,ingress -n dev
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-app   1/1     1            1           17s

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/yatri-app   ClusterIP   10.109.62.182   <none>        80/TCP    17s

$ kubectl get deploy,svc,hpa,ingress -n prod
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-app   3/3     3            3           9s

NAME                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/yatri-app   ClusterIP   10.100.1.209   <none>        80/TCP    9s

NAME                                            REFERENCE              TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/yatri-app   Deployment/yatri-app   cpu: <unknown>/70%   3         10        1          9s

NAME                                  CLASS   HOSTS              ADDRESS   PORTS   AGE
ingress.networking.k8s.io/yatri-app   nginx   yatri-prod.local             80      9s

$ kubectl get deploy yatri-app -n dev  -o jsonpath='dev  image={.spec.template.spec.containers[0].image}'; echo
dev  image=nginx:1.25-alpine

$ kubectl get deploy yatri-app -n prod -o jsonpath='prod image={.spec.template.spec.containers[0].image}'; echo
prod image=nginx:1.26-alpine

$ kubectl get configmap yatri-app-config -n dev  -o jsonpath='{.data.APP_ENV} {.data.LOG_LEVEL}'; echo
development debug

$ kubectl get configmap yatri-app-config -n prod -o jsonpath='{.data.APP_ENV} {.data.LOG_LEVEL}'; echo
production warn

```

## Reach the prod release through the Ingress
```text
$ kubectl get ingress -n prod
NAME        CLASS   HOSTS              ADDRESS   PORTS   AGE
yatri-app   nginx   yatri-prod.local             80      30s

$ minikube ssh -- curl -s -H 'Host:yatri-prod.local' http://localhost/
<html>
  <body>
    <h1>Hello from Helm - PRODUCTION</h1>
    <p>release: yatri-app</p>
    <p>chart:   yatri-app-0.1.0</p>
    <p>app:     1.26-alpine</p>
    <p>env:     production</p>
  </body>
</html>

```

## Secrets and ConfigMap are injected
```text
$ kubectl exec -n prod yatri-app-58fd54444f-rk466 -- sh -c 'echo APP_ENV=$APP_ENV LOG_LEVEL=$LOG_LEVEL RELEASE_NAME=$RELEASE_NAME CHART_VERSION=$CHART_VERSION API_TOKEN_LENGTH=${#API_TOKEN}'
APP_ENV=production LOG_LEVEL=warn RELEASE_NAME=yatri-app CHART_VERSION=0.1.0 API_TOKEN_LENGTH=20

```

## Config change rolls the Pods automatically (checksum annotation)
```text
$ kubectl get deploy yatri-app -n dev -o jsonpath='{.spec.template.metadata.annotations.checksum/config}'; echo
f0a59dab510832f557c9d43cdbf3e0b21b913a02cad7686cf4fe6f1c95f5d683

$ helm upgrade yatri-app ./yatri-app -n dev -f values-dev.yaml --set config.LOG_LEVEL=trace --wait --timeout 3m
Release "yatri-app" has been upgraded. Happy Helming!
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:56:08 2026
NAMESPACE: dev
STATUS: deployed
REVISION: 2
NOTES:
Release "yatri-app" is now revision 2.

  Chart:       yatri-app-0.1.0
  App version: 1.25-alpine
  Namespace:   dev
  Replicas:    1

Reach the application:
  kubectl port-forward -n dev svc/yatri-app 8080:80
  curl http://localhost:8080

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

$ kubectl get deploy yatri-app -n dev -o jsonpath='{.spec.template.metadata.annotations.checksum/config}'; echo
97d1a54e1d3c41238dc5febeb7b7cf3b57e740b4da7b52215bbaea87e0a85aa4

$ kubectl rollout history deploy/yatri-app -n dev
deployment.apps/yatri-app 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>


```

## helm test
```text
$ helm test yatri-app -n prod
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:55:37 2026
NAMESPACE: prod
STATUS: deployed
REVISION: 1
TEST SUITE:     yatri-app-test-connection
Last Started:   Wed Oct  7 21:56:17 2026
Last Completed: Wed Oct  7 21:56:20 2026
Phase:          Succeeded
NOTES:
Release "yatri-app" is now revision 1.

  Chart:       yatri-app-0.1.0
  App version: 1.26-alpine
  Namespace:   prod
  Replicas:    3-10 (HPA)

Reach the application:
  http://yatri-prod.local/

  Add the host to /etc/hosts first:
    echo "$(minikube ip)  yatri-prod.local" | sudo tee -a /etc/hosts

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

```

## Package the chart
```text
$ helm package yatri-app -d "C:/Users/Varun Mundada/AppData/Local/Temp/tmp.3Fz2TEZOVZ"
Successfully packaged chart and saved it to: C:\Users\Varun Mundada\AppData\Local\Temp\tmp.3Fz2TEZOVZ\yatri-app-0.1.0.tgz

$ ls -la "/tmp/tmp.3Fz2TEZOVZ"
total 8200
drwxr-xr-x 1 Varun Mundada 197121    0 Oct  7 21:56 .
drwxr-xr-x 1 Varun Mundada 197121    0 Oct  7 21:56 ..
-rw-r--r-- 1 Varun Mundada 197121 4583 Oct  7 21:56 yatri-app-0.1.0.tgz

$ tar -tzf "/tmp/tmp.3Fz2TEZOVZ/yatri-app-0.1.0.tgz"
yatri-app/Chart.yaml
yatri-app/values.yaml
yatri-app/templates/NOTES.txt
yatri-app/templates/_helpers.tpl
yatri-app/templates/configmap.yaml
yatri-app/templates/deployment.yaml
yatri-app/templates/hpa.yaml
yatri-app/templates/ingress.yaml
yatri-app/templates/secret.yaml
yatri-app/templates/service.yaml
yatri-app/templates/serviceaccount.yaml
yatri-app/templates/tests/test-connection.yaml
yatri-app/.helmignore

```
