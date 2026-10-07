# Evidence — Session 16 CI/CD

Captured locally on Windows 11 + Docker Desktop (Engine 29.7.2), Node 24.17.0.

## 1. Unit tests (`npm test`)

```text
> yatri-cicd-demo@1.0.0 test
> node --test
✔ sum adds two numbers (0.6338ms)
✔ GET / returns the greeting and a version (0.2183ms)
✔ GET /healthz reports ok (1.1898ms)
✔ GET /readyz reports ready (0.1234ms)
✔ GET /sum adds query parameters (0.1416ms)
✔ GET /sum rejects non-numeric input (0.1073ms)
✔ unknown path returns 404 (0.0843ms)
ℹ tests 7
ℹ suites 0
ℹ pass 7
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 85.3902
```

## 2. Docker build — tests run inside the build

The `runtime` stage copies a marker file from the `test` stage, so BuildKit
cannot skip the tests. A failing test fails the image build.

```text
#1 [internal] load build definition from Dockerfile
#2 [internal] load metadata for docker.io/library/node:22-alpine
#3 [internal] load .dockerignore
#4 [internal] load build context
#5 [deps 1/4] FROM docker.io/library/node:22-alpine@sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402
#6 [deps 2/4] WORKDIR /app
#7 [deps 3/4] COPY package.json ./
#8 [test 4/6] COPY src ./src
#9 [test 5/6] COPY test ./test
#10 [test 6/6] RUN npm test && touch /app/.tests-passed
#11 [deps 4/4] RUN npm install --omit=dev --no-audit --no-fund && mkdir -p node_modules
#10 [test 6/6] RUN npm test && touch /app/.tests-passed
#10 0.758 # tests 7
#10 0.759 # pass 7
#10 0.759 # fail 0
#12 [runtime 3/6] COPY --from=test /app/.tests-passed /tmp/.tests-passed
#13 [runtime 4/6] COPY --from=deps --chown=node:node /app/node_modules ./node_modules
#14 [runtime 5/6] COPY --chown=node:node package.json ./
#15 [runtime 6/6] COPY --chown=node:node src ./src
#16 naming to docker.io/library/yatri-cicd-demo:local done
```

## 3. Smoke test of the built image

```text
$ docker run -d --name yatri-smoke -p 3300:3000 yatri-cicd-demo:local
03dcf9e5d18c97eded22e7baf4772dbd7d8d9f0a99b4c6cfce92320a4c315ccd

$ curl http://localhost:3300/
{"message":"Hello World from the CI/CD pipeline","version":"1.0.0"}

$ curl http://localhost:3300/healthz
{"status":"ok"}

$ curl "http://localhost:3300/sum?a=20&b=22"
{"a":20,"b":22,"sum":42}

$ docker exec yatri-smoke id      # non-root
uid=1000(node) gid=1000(node) groups=1000(node)

$ docker ps --filter name=yatri-smoke
NAMES         IMAGE                   STATUS                            PORTS
yatri-smoke   yatri-cicd-demo:local   Up 3 seconds (health: starting)   0.0.0.0:3300->3000/tcp, [::]:3300->3000/tcp

$ docker images yatri-cicd-demo
REPOSITORY        TAG       SIZE
yatri-cicd-demo   local     238MB
```

## 4. Deployed to Kubernetes (minikube)

The same manifests the CD job applies, run against minikube with the locally built image.

```text
$ minikube image load yatri-cicd-demo:latest

$ minikube image ls | grep yatri-cicd-demo
docker.io/library/yatri-cicd-demo:latest

$ kubectl apply -f kubernetes/
deployment.apps/yatri-cicd-demo created
service/yatri-cicd-demo created

$ kubectl rollout status deploy/yatri-cicd-demo --timeout=180s
Waiting for deployment "yatri-cicd-demo" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "yatri-cicd-demo" rollout to finish: 1 of 2 updated replicas are available...
deployment "yatri-cicd-demo" successfully rolled out

$ kubectl get deploy,pods,svc -l app=yatri-cicd-demo -o wide
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                   SELECTOR
deployment.apps/yatri-cicd-demo   2/2     2            2           8s    app          yatri-cicd-demo:latest   app=yatri-cicd-demo

NAME                                  READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
pod/yatri-cicd-demo-b59d49484-mm7hx   1/1     Running   0          8s    10.244.0.192   minikube   <none>           <none>
pod/yatri-cicd-demo-b59d49484-zrv6t   1/1     Running   0          8s    10.244.0.191   minikube   <none>           <none>

NAME                      TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/yatri-cicd-demo   NodePort   10.107.246.27   <none>        80:30080/TCP   8s    app=yatri-cicd-demo

$ minikube ssh -- curl -s http://localhost:30080/
{"message":"Hello World from the CI/CD pipeline","version":"1.0.0"}
$ minikube ssh -- "curl -s 'http://localhost:30080/sum?a=40&b=2'"
{"a":40,"b":2,"sum":42}
$ kubectl describe pod -l app=yatri-cicd-demo | grep -E '^\s+(Liveness|Readiness):' | head -2
    Liveness:   http-get http://:3000/healthz delay=5s timeout=1s period=10s #success=1 #failure=3
    Readiness:  http-get http://:3000/readyz delay=2s timeout=1s period=5s #success=1 #failure=3

$ kubectl logs deploy/yatri-cicd-demo
Found 2 pods, using pod/yatri-cicd-demo-b59d49484-mm7hx
yatri-cicd-demo v1.0.0 listening on port 3000

```
