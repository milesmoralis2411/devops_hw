# Evidence — Helm rollback workflow

Executed with Helm v3.22.0 on minikube v1.39.0 / Kubernetes v1.37.0, 2026-10-07. Output is verbatim.

## 1. Install - revision 1 (nginx 1.25, greeting v1)
```text
$ helm install yatri-app ./yatri-app -n helm-demo --set image.tag=1.25-alpine --set 'config.GREETING=Release v1' --wait --timeout 3m
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:53:43 2026
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

$ helm history yatri-app -n helm-demo
REVISION	UPDATED                 	STATUS  	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 21:53:43 2026	deployed	yatri-app-0.1.0	1.25-alpine	Install complete

```

## 2. Upgrade - revision 2 (nginx 1.26, greeting v2)
```text
$ helm upgrade yatri-app ./yatri-app -n helm-demo --set image.tag=1.26-alpine --set 'config.GREETING=Release v2' --wait --timeout 3m
Release "yatri-app" has been upgraded. Happy Helming!
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:53:52 2026
NAMESPACE: helm-demo
STATUS: deployed
REVISION: 2
NOTES:
Release "yatri-app" is now revision 2.

  Chart:       yatri-app-0.1.0
  App version: 1.26-alpine
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

## 3. Verify
```text
$ helm history yatri-app -n helm-demo
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 21:53:43 2026	superseded	yatri-app-0.1.0	1.25-alpine	Install complete
2       	Wed Oct  7 21:53:52 2026	deployed  	yatri-app-0.1.0	1.25-alpine	Upgrade complete

$ kubectl get pods -n helm-demo -l app.kubernetes.io/instance=yatri-app -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                          IMAGE               STATUS
yatri-app-79c8996554-dw4hw   nginx:1.26-alpine   Running
yatri-app-79c8996554-wmqn9   nginx:1.26-alpine   Running

$ kubectl exec client -- wget -qO- http://yatri-app
<h1>Release v2</h1>
<p>release: yatri-app</p>
<p>chart:   yatri-app-0.1.0</p>
<p>app:     1.26-alpine</p>
<p>env:     production</p>

```

## 4. Upgrade again - revision 3 ships a broken image tag
```text
$ helm upgrade yatri-app ./yatri-app -n helm-demo --set image.tag=9.99-does-not-exist --set 'config.GREETING=Release v3' --wait --timeout 75s
Error: UPGRADE FAILED: context deadline exceeded

```

## 5. Verify - the upgrade failed
```text
$ helm history yatri-app -n helm-demo
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION                                          
1       	Wed Oct  7 21:53:43 2026	superseded	yatri-app-0.1.0	1.25-alpine	Install complete                                     
2       	Wed Oct  7 21:53:52 2026	deployed  	yatri-app-0.1.0	1.25-alpine	Upgrade complete                                     
3       	Wed Oct  7 21:54:07 2026	failed    	yatri-app-0.1.0	1.25-alpine	Upgrade "yatri-app" failed: context deadline exceeded

$ helm status yatri-app -n helm-demo
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:54:07 2026
NAMESPACE: helm-demo
STATUS: failed
REVISION: 3
NOTES:
Release "yatri-app" is now revision 3.

  Chart:       yatri-app-0.1.0
  App version: 9.99-does-not-exist
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

$ kubectl get pods -n helm-demo -l app.kubernetes.io/instance=yatri-app -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.containerStatuses[0].state
POD                          IMAGE                       STATUS
yatri-app-79c8996554-dw4hw   nginx:1.26-alpine           map[running:map[startedAt:2026-10-07T16:23:53Z]]
yatri-app-79c8996554-wmqn9   nginx:1.26-alpine           map[running:map[startedAt:2026-10-07T16:24:00Z]]
yatri-app-868ddf496c-d9sqp   nginx:9.99-does-not-exist   map[waiting:map[reason:ContainerCreating]]

# the rolling update kept the old v2 Pods serving, so users are still on v2
$ kubectl exec client -- wget -qO- http://yatri-app
<h1>Release v2</h1>
<p>release: yatri-app</p>
<p>chart:   yatri-app-0.1.0</p>
<p>app:     1.26-alpine</p>
<p>env:     production</p>

```

## 6. Rollback to revision 2
```text
$ helm rollback yatri-app 2 -n helm-demo --wait --timeout 3m
Rollback was a success! Happy Helming!

```

## 7. Verify
```text
$ helm history yatri-app -n helm-demo
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION                                          
1       	Wed Oct  7 21:53:43 2026	superseded	yatri-app-0.1.0	1.25-alpine	Install complete                                     
2       	Wed Oct  7 21:53:52 2026	superseded	yatri-app-0.1.0	1.25-alpine	Upgrade complete                                     
3       	Wed Oct  7 21:54:07 2026	failed    	yatri-app-0.1.0	1.25-alpine	Upgrade "yatri-app" failed: context deadline exceeded
4       	Wed Oct  7 21:55:23 2026	deployed  	yatri-app-0.1.0	1.25-alpine	Rollback to 2                                        

$ helm status yatri-app -n helm-demo
NAME: yatri-app
LAST DEPLOYED: Wed Oct  7 21:55:23 2026
NAMESPACE: helm-demo
STATUS: deployed
REVISION: 4
NOTES:
Release "yatri-app" is now revision 2.

  Chart:       yatri-app-0.1.0
  App version: 1.26-alpine
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

$ kubectl get pods -n helm-demo -l app.kubernetes.io/instance=yatri-app -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase
POD                          IMAGE                       STATUS
yatri-app-79c8996554-dw4hw   nginx:1.26-alpine           Running
yatri-app-79c8996554-wmqn9   nginx:1.26-alpine           Running
yatri-app-868ddf496c-d9sqp   nginx:9.99-does-not-exist   Pending

$ kubectl exec client -- wget -qO- http://yatri-app
<h1>Release v2</h1>
<p>release: yatri-app</p>
<p>chart:   yatri-app-0.1.0</p>
<p>app:     1.26-alpine</p>
<p>env:     production</p>

$ helm get values yatri-app -n helm-demo
USER-SUPPLIED VALUES:
config:
  GREETING: Release v2
image:
  tag: 1.26-alpine

```
