# Evidence — Helm commands

Executed with Helm v3.22.0 on minikube v1.39.0 / Kubernetes v1.37.0, 2026-10-07. Output is verbatim.

## helm version
```text
$ helm version
version.BuildInfo{Version:"v3.22.0", GitCommit:"144ca65f8501953fa8b41cd1d37c7223051c85b7", GitTreeState:"clean", GoVersion:"go1.26.8"}

```

## helm create - scaffold a new chart
```text
$ helm create demo-chart
Creating demo-chart

$ find demo-chart -type f | sort
demo-chart/.helmignore
demo-chart/Chart.yaml
demo-chart/templates/NOTES.txt
demo-chart/templates/_helpers.tpl
demo-chart/templates/deployment.yaml
demo-chart/templates/hpa.yaml
demo-chart/templates/httproute.yaml
demo-chart/templates/ingress.yaml
demo-chart/templates/service.yaml
demo-chart/templates/serviceaccount.yaml
demo-chart/templates/tests/test-connection.yaml
demo-chart/values.yaml

$ helm lint demo-chart
==> Linting demo-chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

```

## helm template / lint - render locally without a cluster
```text
$ helm lint yatri-app
==> Linting yatri-app
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template yatri-app ./yatri-app | grep -E '^(kind|  name):'
kind: ServiceAccount
  name: yatri-app
kind: Secret
  name: yatri-app-secret
kind: ConfigMap
  name: yatri-app-config
kind: Service
  name: yatri-app
kind: Deployment
  name: yatri-app
kind: Ingress
  name: yatri-app
kind: Pod
  name: "yatri-app-test-connection"

```

## helm install
```text
$ helm install yatri-app ./yatri-app --namespace helm-demo --wait --timeout 3m
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:49:52 2026
NAMESPACE: helm-demo
STATUS: deployed
REVISION: 1
NOTES:
Release "yatri-app" is now revision 1.

  Chart:       yatri-app-0.1.0
  App version: 1.25-alpine
  Namespace:   helm-demo
  Replicas:    2

Reach the application:
  http://yatri-helm.local/

  Add the host to /etc/hosts first:
    echo "$(minikube ip)  yatri-helm.local" | sudo tee -a /etc/hosts

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

```

## helm list
```text
$ helm list -n helm-demo
NAME     	NAMESPACE	REVISION	UPDATED                              	STATUS  	CHART          	APP VERSION
yatri-app	helm-demo	1       	2026-10-07 21:49:52.8271156 +0530 IST	deployed	yatri-app-0.1.0	1.25-alpine

$ helm list -A
NAME     	NAMESPACE	REVISION	UPDATED                              	STATUS  	CHART          	APP VERSION
yatri-app	helm-demo	1       	2026-10-07 21:49:52.8271156 +0530 IST	deployed	yatri-app-0.1.0	1.25-alpine

```

## helm status
```text
$ helm status yatri-app -n helm-demo
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:49:52 2026
NAMESPACE: helm-demo
STATUS: deployed
REVISION: 1
NOTES:
Release "yatri-app" is now revision 1.

  Chart:       yatri-app-0.1.0
  App version: 1.25-alpine
  Namespace:   helm-demo
  Replicas:    2

Reach the application:
  http://yatri-helm.local/

  Add the host to /etc/hosts first:
    echo "$(minikube ip)  yatri-helm.local" | sudo tee -a /etc/hosts

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

```

## helm get
```text
$ helm get values yatri-app -n helm-demo
USER-SUPPLIED VALUES:
null

$ helm get values yatri-app -n helm-demo --all | head -25
COMPUTED VALUES:
affinity: {}
autoscaling:
  enabled: false
  maxReplicas: 8
  minReplicas: 2
  targetCPUUtilizationPercentage: 70
config:
  APP_ENV: production
  APP_NAME: Yatri App
  GREETING: Hello from Helm
  LOG_LEVEL: info
fullnameOverride: ""
image:
  pullPolicy: IfNotPresent
  repository: nginx
  tag: 1.25-alpine
imagePullSecrets: []
ingress:
  annotations: {}
  className: nginx
  enabled: true
  hosts:
  - host: yatri-helm.local
    paths:

$ helm get manifest yatri-app -n helm-demo | grep -E '^(kind|  name):'
kind: ServiceAccount
  name: yatri-app
kind: Secret
  name: yatri-app-secret
kind: ConfigMap
  name: yatri-app-config
kind: Service
  name: yatri-app
kind: Deployment
  name: yatri-app
kind: Ingress
  name: yatri-app

$ helm get metadata yatri-app -n helm-demo
NAME: yatri-app
CHART: yatri-app
VERSION: 0.1.0
APP_VERSION: 1.25-alpine
ANNOTATIONS: 
DEPENDENCIES: 
NAMESPACE: helm-demo
REVISION: 1
STATUS: deployed
DEPLOYED_AT: 2026-10-07T21:49:52+05:30

$ helm get notes yatri-app -n helm-demo | head -8
NOTES:
Release "yatri-app" is now revision 1.

  Chart:       yatri-app-0.1.0
  App version: 1.25-alpine
  Namespace:   helm-demo
  Replicas:    2


```

## The release is real Kubernetes objects
```text
$ kubectl get all,configmap,secret,ingress -n helm-demo -l app.kubernetes.io/instance=yatri-app
NAME                             READY   STATUS    RESTARTS   AGE
pod/yatri-app-7c89569f48-5kz4m   1/1     Running   0          9s
pod/yatri-app-7c89569f48-lgg5c   1/1     Running   0          9s

NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/yatri-app   ClusterIP   10.100.211.136   <none>        80/TCP    9s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-app   2/2     2            2           9s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/yatri-app-7c89569f48   2         2         2       9s

NAME                         DATA   AGE
configmap/yatri-app-config   5      9s

NAME                      TYPE     DATA   AGE
secret/yatri-app-secret   Opaque   2      9s

NAME                                  CLASS   HOSTS              ADDRESS   PORTS   AGE
ingress.networking.k8s.io/yatri-app   nginx   yatri-helm.local             80      9s

$ kubectl exec client -- wget -qO- http://yatri-app
<h1>Hello from Helm</h1>
<p>release: yatri-app</p>
<p>chart:   yatri-app-0.1.0</p>
<p>app:     1.25-alpine</p>
<p>env:     production</p>

```

## helm upgrade
```text
$ helm upgrade yatri-app ./yatri-app -n helm-demo --set replicaCount=3 --set 'config.GREETING=Hello from Helm - upgraded' --wait --timeout 3m
Release "yatri-app" has been upgraded. Happy Helming!
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:50:02 2026
NAMESPACE: helm-demo
STATUS: deployed
REVISION: 2
NOTES:
Release "yatri-app" is now revision 2.

  Chart:       yatri-app-0.1.0
  App version: 1.25-alpine
  Namespace:   helm-demo
  Replicas:    3

Reach the application:
  http://yatri-helm.local/

  Add the host to /etc/hosts first:
    echo "$(minikube ip)  yatri-helm.local" | sudo tee -a /etc/hosts

Useful commands:

  helm status yatri-app
  helm get values yatri-app
  helm history yatri-app
  helm rollback yatri-app <REVISION>

$ kubectl get deploy yatri-app -n helm-demo
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
yatri-app   3/3     3            3           32s

$ kubectl exec client -- wget -qO- http://yatri-app
<h1>Hello from Helm - upgraded</h1>
<p>release: yatri-app</p>
<p>chart:   yatri-app-0.1.0</p>
<p>app:     1.25-alpine</p>
<p>env:     production</p>

```

## helm history
```text
$ helm history yatri-app -n helm-demo
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 21:49:52 2026	superseded	yatri-app-0.1.0	1.25-alpine	Install complete
2       	Wed Oct  7 21:50:02 2026	deployed  	yatri-app-0.1.0	1.25-alpine	Upgrade complete

```

## helm rollback
```text
$ helm rollback yatri-app 1 -n helm-demo --wait --timeout 3m
Rollback was a success! Happy Helming!

$ helm history yatri-app -n helm-demo
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 21:49:52 2026	superseded	yatri-app-0.1.0	1.25-alpine	Install complete
2       	Wed Oct  7 21:50:02 2026	superseded	yatri-app-0.1.0	1.25-alpine	Upgrade complete
3       	Wed Oct  7 21:50:26 2026	deployed  	yatri-app-0.1.0	1.25-alpine	Rollback to 1   

$ kubectl get deploy yatri-app -n helm-demo
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
yatri-app   2/2     2            2           47s

$ kubectl exec client -- wget -qO- http://yatri-app
<h1>Hello from Helm</h1>
<p>release: yatri-app</p>
<p>chart:   yatri-app-0.1.0</p>
<p>app:     1.25-alpine</p>
<p>env:     production</p>

```

## helm uninstall
```text
$ helm uninstall yatri-app -n helm-demo --wait
release "yatri-app" uninstalled

$ helm list -n helm-demo
NAME	NAMESPACE	REVISION	UPDATED	STATUS	CHART	APP VERSION

$ kubectl get all -n helm-demo -l app.kubernetes.io/instance=yatri-app
NAME                             READY   STATUS        RESTARTS   AGE
pod/yatri-app-7c89569f48-b4btw   1/1     Terminating   0          15s
pod/yatri-app-7c89569f48-fnhd5   0/1     Completed     0          9s

```

## helm repo
```text
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
"ingress-nginx" already exists with the same configuration, skipping

$ helm repo add jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories

$ helm repo list
NAME         	URL                                       
argo         	https://argoproj.github.io/argo-helm      
ingress-nginx	https://kubernetes.github.io/ingress-nginx
jetstack     	https://charts.jetstack.io                

$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "ingress-nginx" chart repository
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "argo" chart repository
Update Complete. ⎈Happy Helming!⎈

```

## helm search
```text
$ helm search repo ingress-nginx
NAME                       	CHART VERSION	APP VERSION	DESCRIPTION                                       
ingress-nginx/ingress-nginx	4.15.1       	1.15.1     	Ingress controller for Kubernetes using NGINX a...

$ helm search repo ingress-nginx/ingress-nginx --versions | head -6
NAME                       	CHART VERSION	APP VERSION	DESCRIPTION                                       
ingress-nginx/ingress-nginx	4.15.1       	1.15.1     	Ingress controller for Kubernetes using NGINX a...
ingress-nginx/ingress-nginx	4.15.0       	1.15.0     	Ingress controller for Kubernetes using NGINX a...
ingress-nginx/ingress-nginx	4.14.5       	1.14.5     	Ingress controller for Kubernetes using NGINX a...
ingress-nginx/ingress-nginx	4.14.4       	1.14.4     	Ingress controller for Kubernetes using NGINX a...
ingress-nginx/ingress-nginx	4.14.3       	1.14.3     	Ingress controller for Kubernetes using NGINX a...

$ helm search repo jetstack/cert-manager
NAME                                   	CHART VERSION	APP VERSION	DESCRIPTION                                       
jetstack/cert-manager                  	v1.21.2      	v1.21.2    	A Helm chart for cert-manager                     
jetstack/cert-manager-approver-policy  	v0.28.0      	v0.28.0    	approver-policy is a CertificateRequest approve...
jetstack/cert-manager-csi-driver       	v0.16.0      	v0.16.0    	cert-manager csi-driver enables issuing secretl...
jetstack/cert-manager-csi-driver-spiffe	v0.15.0      	v0.15.0    	csi-driver-spiffe is a Kubernetes CSI plugin wh...
jetstack/cert-manager-google-cas-issuer	v0.13.0      	v0.13.0    	A Helm chart for jetstack/google-cas-issuer       
jetstack/cert-manager-istio-csr        	v0.18.0      	v0.18.0    	istio-csr enables the use of cert-manager for i...
jetstack/cert-manager-trust            	v0.2.1       	v0.2.0     	DEPRECATED: The old name for trust-manager. Use...

$ helm search hub argo-cd --max-col-width 60 | head -6
URL                                                         	CHART VERSION	APP VERSION	DESCRIPTION                                                 
https://artifacthub.io/packages/helm/spnngl-argo-cd-crds/...	3.5.6        	3.5.4      	CustomResourceDefinitions for Argo CD (Applications, Appl...
https://artifacthub.io/packages/helm/emberstack/argo-cd-e...	1.0.22       	1.0.0      	A Helm chart for Argo CD extensions                         
https://artifacthub.io/packages/helm/argo-cd-oci/argo-cd    	10.10.0      	v3.5.4     	A Helm chart for Argo CD, a declarative, GitOps continuou...
https://artifacthub.io/packages/helm/mesosphere-stable/ar...	0.5.4        	1.2.0      	A Helm chart for Argo-CD                                    
https://artifacthub.io/packages/helm/capsule-argo-addon/c...	0.8.0        	0.8.0      	Capsule Argo Addon                                          

$ helm show chart ingress-nginx/ingress-nginx
annotations:
  artifacthub.io/changes: |
    - Update Ingress-Nginx version controller-v1.15.1
  artifacthub.io/prerelease: "false"
apiVersion: v2
appVersion: 1.15.1
description: Ingress controller for Kubernetes using NGINX as a reverse proxy and
  load balancer
home: https://github.com/kubernetes/ingress-nginx
icon: https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Nginx_logo.svg/500px-Nginx_logo.svg.png
keywords:
- ingress
- nginx
kubeVersion: '>=1.21.0-0'
maintainers:
- name: cpanato
- name: Gacko
- name: strongjz
- name: tao12345666333
name: ingress-nginx
sources:
- https://github.com/kubernetes/ingress-nginx
version: 4.15.1


$ helm show values ingress-nginx/ingress-nginx | head -20
## nginx configuration
## Ref: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/index.md
##

global:
  image:
    # -- Registry host to pull images from.
    registry: registry.k8s.io
## Overrides for generated resource names
# See templates/_helpers.tpl
# nameOverride:
# fullnameOverride:

# -- Override the deployment namespace; defaults to .Release.Namespace
namespaceOverride: ""
## Labels to apply to all resources
##
commonLabels: {}
# scmhash: abc123
# myLabel: aakkmd

$ helm repo remove jetstack
"jetstack" has been removed from your repositories

$ helm repo list
NAME         	URL                                       
argo         	https://argoproj.github.io/argo-helm      
ingress-nginx	https://kubernetes.github.io/ingress-nginx

```
