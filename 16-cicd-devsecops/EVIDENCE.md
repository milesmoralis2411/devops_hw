# Evidence — DevSecOps pipeline, every stage run locally

Executed 2026-10-07 on Windows 11 + Docker Desktop with the same tools the workflow uses: Semgrep 1.179.0, npm audit, Trivy 0.57.1, Gitleaks 8.21.2, then the hardened manifests on minikube (Kubernetes v1.37.0). Output is verbatim; ANSI colour codes from Gitleaks are left as captured.

Order note: sections 1–7 are one run. Section 3 was re-captured after a package-lock.json was added (npm audit needs one), and section 5b shows the image rebuilt after the remediation that section 5 called for.

## 1. Build + unit tests
```text
$ npm test

> yatri-cicd-demo@1.0.0 test
> node --test

✔ sum adds two numbers (1.8602ms)
✔ GET / returns the greeting and a version (0.7916ms)
✔ GET /healthz reports ok (5.421ms)
✔ GET /readyz reports ready (0.2955ms)
✔ GET /sum adds query parameters (0.2708ms)
✔ GET /sum rejects non-numeric input (0.2089ms)
✔ unknown path returns 404 (0.3481ms)
ℹ tests 7
ℹ suites 0
ℹ pass 7
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 185.6477

```

## 2. SAST - Semgrep
```text
$ semgrep --version
1.179.0

$ semgrep scan --config=p/javascript --config=p/security-audit --metrics=off --quiet src 2>&1 | tail -25

# The same scanner against a deliberately vulnerable snippet, to prove it fires:
$ semgrep scan --config=p/javascript --config=p/security-audit --metrics=off --quiet sast-demo 2>&1 | grep -vE '^\s*$' | head -40
┌────────────────┐
│ 1 Code Finding │
└────────────────┘
    sast-demo\bad.js
   ❯❯❱ javascript.lang.security.detect-child-process.detect-child-process
          ❰❰ Blocking ❱❱
          Detected calls to child_process from a function argument `req`. This could lead to a command  
          injection if the input is user controllable. Try to avoid calls to child_process, and if it is
          needed ensure user input is correctly sanitized or sandboxed.                                 
          Details: https://sg.run/l2lo                                                                  
            5┆ exec('ls ' + name, (e, out) => res.end(out));          // command injection

```

## 3. SCA - dependency vulnerabilities
```text
# npm audit needs a lockfile; package-lock.json is now committed (and the Dockerfile uses npm ci)
$ npm audit --audit-level=high
found 0 vulnerabilities

$ docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v "C:/Users/Varun Mundada/Desktop/devops-hw/15-cicd-github-actions/app:/src" aquasec/trivy:0.57.1 fs --skip-check-update --scanners vuln,misconfig --severity HIGH,CRITICAL --exit-code 1 /src 2>&1 | grep -v INFO; echo "trivy exit code: ${PIPESTATUS[0]} (0 = no HIGH/CRITICAL vulnerabilities or misconfigurations)"
trivy exit code: 0 (0 = no HIGH/CRITICAL vulnerabilities or misconfigurations)

```

## 4. Secret scanning - Gitleaks
```text
$ docker run --rm -v "C:/Users/Varun Mundada/Desktop/devops-hw:/repo" zricethezav/gitleaks:v8.21.2 detect --source /repo --config /repo/16-cicd-devsecops/security/gitleaks.toml --no-banner --redact -v 2>&1 | tail -15
Finding:     POSTGRES_PASSWORD: [1;3;mREDACTED[0m
Secret:      [1;3;mREDACTED[0m
RuleID:      generic-api-key
Entropy:     4.001629
File:        11-kubernetes-ingress-configmaps-secrets/full-demo/secret.yaml
Line:        14
Commit:      47f0f69a5754627d645a2a15e20cef6a33331028
Author:      Varun Mundada
Email:       varunmundada971@gmail.com
Date:        2026-09-17T16:19:07Z
Fingerprint: 47f0f69a5754627d645a2a15e20cef6a33331028:11-kubernetes-ingress-configmaps-secrets/full-demo/secret.yaml:generic-api-key:14

[90m5:05PM[0m [32mINF[0m 9 commits scanned.
[90m5:05PM[0m [32mINF[0m scan completed in 5.6s
[90m5:05PM[0m [31mWRN[0m leaks found: 1

# Proving the scanner works: a throwaway repo with a fake AWS key committed
warning: in the working copy of 'config.ini', LF will be replaced by CRLF the next time Git touches it
$ docker run --rm -v "C:/Users/Varun Mundada/AppData/Local/Temp/leak-demo:/repo" zricethezav/gitleaks:v8.21.2 detect --source /repo --no-banner --redact -v 2>&1 | tail -25
[90m5:05PM[0m [32mINF[0m 1 commits scanned.
[90m5:05PM[0m [32mINF[0m scan completed in 421ms
[90m5:05PM[0m [31mWRN[0m leaks found: 1
Finding:     aws_access_key_id = [1;3;mREDACTED[0m
Secret:      [1;3;mREDACTED[0m
RuleID:      aws-access-token
Entropy:     3.484184
File:        config.ini
Line:        1
Commit:      d209e54d0cdda67e991a3b6cca9370fedd90177b
Author:      demo
Email:       demo@example.com
Date:        2026-10-07T17:05:02Z
Fingerprint: d209e54d0cdda67e991a3b6cca9370fedd90177b:config.ini:aws-access-token:1


```

## 5. Docker build + container image scan - Trivy (BEFORE remediation)
```text
$ docker build -q -t yatri-secure:scan .
sha256:6208ececf8402473ccff6c4452444c51efb8ca54ff2842d5e1e270909322b9f7

$ docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.57.1 image --severity HIGH,CRITICAL --ignore-unfixed --quiet yatri-secure:scan

yatri-secure:scan (alpine 3.24.2)
=================================
Total: 0 (HIGH: 0, CRITICAL: 0)


Node.js (node-pkg)
==================
Total: 10 (HIGH: 10, CRITICAL: 0)

┌────────────────────────────────┬─────────────────┬──────────┬────────┬───────────────────┬──────────────────────────────┬────────────────────────────────────────────────────────────┐
│            Library             │  Vulnerability  │ Severity │ Status │ Installed Version │        Fixed Version         │                           Title                            │
├────────────────────────────────┼─────────────────┼──────────┼────────┼───────────────────┼──────────────────────────────┼────────────────────────────────────────────────────────────┤
│ brace-expansion (package.json) │ CVE-2026-102276 │ HIGH     │ fixed  │ 2.0.2             │ 5.0.10, 3.0.7, 2.1.5, 1.1.19 │ brace-expansion: brace-expansion: Denial of Service via    │
│                                │                 │          │        │                   │                              │ stack exhaustion from crafted brace patterns...            │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-102276                │
│                                ├─────────────────┤          │        │                   ├──────────────────────────────┼────────────────────────────────────────────────────────────┤
│                                │ CVE-2026-102278 │          │        │                   │ 5.0.11, 3.0.8, 2.1.6, 1.1.20 │ brace-expansion: brace-expansion: Denial of Service via    │
│                                │                 │          │        │                   │                              │ uncontrolled recursion in nested brace patterns...         │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-102278                │
│                                ├─────────────────┤          │        │                   ├──────────────────────────────┼────────────────────────────────────────────────────────────┤
│                                │ CVE-2026-13149  │          │        │                   │ 5.0.7, 1.1.16, 2.1.2         │ brace-expansion: Brace-expansion: Denial of Service due to │
│                                │                 │          │        │                   │                              │ exponential-time complexity                                │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-13149                 │
│                                ├─────────────────┤          │        │                   ├──────────────────────────────┼────────────────────────────────────────────────────────────┤
│                                │ CVE-2026-14257  │          │        │                   │ 5.0.8, 3.0.3, 2.1.3, 1.1.17  │ brace-expansion: Brace-expansion: Denial of Service via    │
│                                │                 │          │        │                   │                              │ memory exhaustion in expand() function                     │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-14257                 │
│                                ├─────────────────┤          │        │                   ├──────────────────────────────┼────────────────────────────────────────────────────────────┤
│                                │ CVE-2026-69152  │          │        │                   │ 1.1.18, 2.1.4, 3.0.6, 5.0.9  │ brace-expansion: DoS via unbounded intermediate arrays,    │
│                                │                 │          │        │                   │                              │ bypassing the CVE-2026-14257 mitigation                    │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-69152                 │
├────────────────────────────────┼─────────────────┤          │        ├───────────────────┼──────────────────────────────┼────────────────────────────────────────────────────────────┤
│ ip-address (package.json)      │ CVE-2026-69192  │          │        │ 10.1.0            │ 10.3.1                       │ ip-address: ip-address: Inconsistent IP address parsing    │
│                                │                 │          │        │                   │                              │ leads to Server-Side Request Forgery (SSRF)...             │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-69192                 │
├────────────────────────────────┼─────────────────┤          │        ├───────────────────┼──────────────────────────────┼────────────────────────────────────────────────────────────┤
│ pacote (package.json)          │ CVE-2026-9496   │          │        │ 19.0.2            │ 21.5.1                       │ pacote: Pacote: Denial of Service via crafted spec.rawSpec │
│                                │                 │          │        │                   │                              │ value in addGitSha function...                             │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-9496                  │
│                                │                 │          │        ├───────────────────┤                              │                                                            │
│                                │                 │          │        │ 20.0.1            │                              │                                                            │
│                                │                 │          │        │                   │                              │                                                            │
│                                │                 │          │        │                   │                              │                                                            │
├────────────────────────────────┼─────────────────┤          │        ├───────────────────┼──────────────────────────────┼────────────────────────────────────────────────────────────┤
│ picomatch (package.json)       │ CVE-2026-33671  │          │        │ 4.0.3             │ 4.0.4, 3.0.2, 2.3.2          │ picomatch: Picomatch: Regular Expression Denial of Service │
│                                │                 │          │        │                   │                              │ via crafted extglob patterns                               │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-33671                 │
├────────────────────────────────┼─────────────────┤          │        ├───────────────────┼──────────────────────────────┼────────────────────────────────────────────────────────────┤
│ sigstore (package.json)        │ CVE-2026-48815  │          │        │ 3.1.0             │ 4.1.1                        │ sigstore: Sigstore: Unauthorized certificates accepted due │
│                                │                 │          │        │                   │                              │ to ignored `certificateOIDs` verification option           │
│                                │                 │          │        │                   │                              │ https://avd.aquasec.com/nvd/cve-2026-48815                 │
└────────────────────────────────┴─────────────────┴──────────┴────────┴───────────────────┴──────────────────────────────┴────────────────────────────────────────────────────────────┘

```

## 5b. Remediation - remove npm/yarn/corepack from the runtime image, rescan
```text
$ grep -n -A3 'RUN rm -rf' Dockerfile
29:RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
30-           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
31-           /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg
32-

$ docker build -q -t yatri-secure:scan .
sha256:88e3ccc92cc7cc6475b8941366e21027f02c005bccf6bd82da59a24a46c4e842

$ docker run --rm yatri-secure:scan sh -c 'ls /usr/local/bin; which npm || echo npm: not present'
docker-entrypoint.sh
node
nodejs
npm: not present

# AFTER - compare section 5, where the Node.js (npm bundled deps) part had 10 HIGH
$ docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.57.1 image --severity HIGH,CRITICAL --ignore-unfixed --quiet yatri-secure:scan

yatri-secure:scan (alpine 3.24.2)
=================================
Total: 0 (HIGH: 0, CRITICAL: 0)


$ docker images yatri-secure:scan --format 'size: {{.Size}}'
size: 238MB

```

## 6. Security gate
```text
Policy: block the release on any fixable CRITICAL vulnerability.
CRITICAL found: 0
SECURITY GATE: PASSED

# Trivy can enforce the same gate directly through its exit code:
$ docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.57.1 image --severity CRITICAL --ignore-unfixed --exit-code 1 --quiet yatri-secure:scan; echo "trivy exit code: $?"

yatri-secure:scan (alpine 3.24.2)
=================================
Total: 0 (CRITICAL: 0)

trivy exit code: 0

# ...and against an old, unpatched base image the gate fails as designed:
$ docker run --rm -v yatri-trivy-cache:/root/.cache/trivy -v //var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.57.1 image --severity CRITICAL --ignore-unfixed --exit-code 1 --quiet node:14-alpine 2>&1 | tail -12; echo "trivy exit code: ${PIPESTATUS[0]}"
==================
Total: 2 (CRITICAL: 2)

┌──────────────────────────┬────────────────┬──────────┬────────┬───────────────────┬─────────────────────┬────────────────────────────────────────────────────────┐
│         Library          │ Vulnerability  │ Severity │ Status │ Installed Version │    Fixed Version    │                         Title                          │
├──────────────────────────┼────────────────┼──────────┼────────┼───────────────────┼─────────────────────┼────────────────────────────────────────────────────────┤
│ form-data (package.json) │ CVE-2025-7783  │ CRITICAL │ fixed  │ 2.3.3             │ 2.5.4, 3.0.4, 4.0.4 │ form-data: Unsafe random function in form-data         │
│                          │                │          │        │                   │                     │ https://avd.aquasec.com/nvd/cve-2025-7783              │
├──────────────────────────┼────────────────┤          │        ├───────────────────┼─────────────────────┼────────────────────────────────────────────────────────┤
│ tar (package.json)       │ CVE-2026-59873 │          │        │ 4.4.19            │ 7.5.19              │ tar: node-tar: Denial of Service via crafted gzip bomb │
│                          │                │          │        │                   │                     │ https://avd.aquasec.com/nvd/cve-2026-59873             │
└──────────────────────────┴────────────────┴──────────┴────────┴───────────────────┴─────────────────────┴────────────────────────────────────────────────────────┘
trivy exit code: 1

```

## 7. Deploy the hardened manifests to Kubernetes
```text
$ kubectl create namespace devsecops
namespace/devsecops created

$ kubectl apply -n devsecops -f kubernetes/
deployment.apps/yatri-secure created
service/yatri-secure created
networkpolicy.networking.k8s.io/yatri-secure-default-deny created
networkpolicy.networking.k8s.io/yatri-secure-allow created

$ kubectl -n devsecops rollout status deploy/yatri-secure --timeout=180s
Waiting for deployment "yatri-secure" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "yatri-secure" rollout to finish: 1 of 2 updated replicas are available...
deployment "yatri-secure" successfully rolled out

$ kubectl -n devsecops get deploy,pods,svc,networkpolicy
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/yatri-secure   2/2     2            2           9s

NAME                                READY   STATUS    RESTARTS   AGE
pod/yatri-secure-6cf896f97b-68s8g   1/1     Running   0          9s
pod/yatri-secure-6cf896f97b-cs88f   1/1     Running   0          9s

NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/yatri-secure   ClusterIP   10.102.175.144   <none>        80/TCP    9s

NAME                                                        POD-SELECTOR       AGE
networkpolicy.networking.k8s.io/yatri-secure-allow          app=yatri-secure   8s
networkpolicy.networking.k8s.io/yatri-secure-default-deny   app=yatri-secure   8s

$ kubectl -n devsecops exec yatri-secure-6cf896f97b-68s8g -- id
uid=1000(node) gid=1000(node) groups=1000(node)

$ kubectl -n devsecops exec yatri-secure-6cf896f97b-68s8g -- sh -c 'touch /app/hacked' 
touch: /app/hacked: Read-only file system
command terminated with exit code 1

$ kubectl -n devsecops exec yatri-secure-6cf896f97b-68s8g -- sh -c 'touch /tmp/allowed && echo /tmp is writable'
/tmp is writable

$ kubectl -n devsecops get pod yatri-secure-6cf896f97b-68s8g -o jsonpath='{.spec.containers[0].securityContext}'; echo
{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"privileged":false,"readOnlyRootFilesystem":true}

$ kubectl -n devsecops run curl --image=busybox:1.36 --restart=Never --rm -i --quiet -- wget -qO- http://yatri-secure
wget: can't connect to remote host (10.102.175.144): Connection timed out
pod devsecops/curl terminated (Error)

```
