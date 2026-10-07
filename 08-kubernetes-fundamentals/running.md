# Commands used

Every command for the Kubernetes Fundamentals tasks, in the order they were
run. The output is in the [README](README.md) screenshots and in
[EVIDENCE.md](EVIDENCE.md).

## 1. Install and configure Minikube (Windows, Docker Desktop)

```powershell
# Install: either a package manager ...
winget install Kubernetes.minikube
# ... or the release binary, as used here (minikube v1.39.0):
#   https://github.com/kubernetes/minikube/releases -> minikube-windows-amd64.exe, renamed to minikube.exe on PATH

# kubectl ships with Docker Desktop; or: winget install Kubernetes.kubectl
```

```bash
minikube start --driver=docker --container-runtime=containerd \
  --kubernetes-version=v1.37.0 --cpus=2 --memory=4096
minikube addons enable metrics-server     # kubectl top, HPA (later sessions)
```

The Ingress controller used from Session 12 onwards is **ingress-nginx v1.15.1**,
installed with `kubectl apply` (NodePort Service, default IngressClass `nginx`,
`--watch-ingress-without-class=true`). `minikube addons enable ingress` sets up the
same controller in one command.

## 2. Verify the cluster status

```bash
minikube version
minikube status
minikube profile list
kubectl config current-context            # minikube
kubectl cluster-info
kubectl get nodes -o wide
kubectl get --raw='/readyz?verbose'
kubectl get pods -n kube-system           # the control plane, running as Pods
```

## 3. Cluster architecture

```bash
kubectl version
kubectl get nodes -o wide
kubectl describe node minikube
kubectl get pods -n kube-system -o wide   # etcd, kube-apiserver, kube-scheduler,
                                          # kube-controller-manager, kube-proxy, coredns
```

## 4. kubectl basics

```bash
kubectl apply -f 02-kubectl-basics/hello-pod.yaml
kubectl get pods -o wide
kubectl describe pod hello-kubectl
kubectl logs hello-kubectl
kubectl exec -it hello-kubectl -- sh       # hostname; cat /usr/share/nginx/html/index.html
kubectl port-forward pod/hello-kubectl 8080:80
curl http://localhost:8080                 # in a second terminal
kubectl delete -f 02-kubectl-basics/hello-pod.yaml
```

## 5. Namespaces

```bash
kubectl apply -f 03-namespaces/namespaces.yaml
kubectl apply -f 03-namespaces/app-dev.yaml -f 03-namespaces/app-prod.yaml
kubectl get deploy,svc -n yatri-dev
kubectl get deploy,svc -n yatri-prod
kubectl get pods                           # nothing: the default namespace is empty

kubectl apply -f 03-namespaces/client-pod.yaml
kubectl exec -n yatri-dev ns-test-client -- curl -s web-service
kubectl exec -n yatri-dev ns-test-client -- curl -s web-service.yatri-prod.svc.cluster.local

kubectl delete namespace yatri-dev yatri-prod
```

## 6. Kubernetes Basics tutorial (hands-on)

The official tutorial (kubernetes.io/docs/tutorials/kubernetes-basics), module by module.

```bash
# Deploy an app
kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1
kubectl get deployments

# Explore the app
kubectl get pods -o wide
kubectl describe pod <pod>
kubectl logs <pod>
kubectl exec <pod> -- env
kubectl exec <pod> -- curl -s http://localhost:8080

# Expose the app, and use labels
kubectl expose deployment/kubernetes-bootcamp --type=NodePort --port 8080
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -o go-template='{{(index .spec.ports 0).nodePort}}')
minikube ssh -- curl -s http://localhost:$NODE_PORT
kubectl label pods <pod> version=v1
kubectl get pods -l version=v1
kubectl delete service -l app=kubernetes-bootcamp

# Scale the app
kubectl scale deployments/kubernetes-bootcamp --replicas=4
kubectl get pods -o wide
kubectl scale deployments/kubernetes-bootcamp --replicas=2

# Update the app, then roll back a bad update
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2
kubectl rollout status deployments/kubernetes-bootcamp
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=gcr.io/google-samples/kubernetes-bootcamp:v10
kubectl get pods                           # ImagePullBackOff
kubectl rollout undo deployments/kubernetes-bootcamp
kubectl rollout history deployments/kubernetes-bootcamp

# Clean up
kubectl delete service,deployment kubernetes-bootcamp
```
