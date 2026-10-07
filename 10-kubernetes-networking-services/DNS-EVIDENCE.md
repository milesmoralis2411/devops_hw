# Evidence — Cluster DNS, FQDN and CoreDNS

Executed on minikube v1.39.0 / Kubernetes v1.37.0, 2026-10-07. Output is verbatim.

Setup: an nginx `backend` Service in namespace `production`, and a client Pod `dnsclient` in `default`.

## CoreDNS in the cluster
```text
$ kubectl get deployment coredns -n kube-system
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
coredns   1/1     1            1           24m

$ kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
coredns-559f6c778d-zndtf   1/1     Running   0          23m   10.244.0.2   minikube   <none>           <none>

$ kubectl get svc kube-dns -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   23m

$ kubectl get endpointslices -n kube-system -l kubernetes.io/service-name=kube-dns
NAME             ADDRESSTYPE   PORTS        ENDPOINTS    AGE
kube-dns-9b8m7   IPv4          53,53,9153   10.244.0.2   23m

$ kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'
.:53 {
    log
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    hosts {
       192.168.65.254 host.minikube.internal
       fallthrough
    }
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30 {
       disable success cluster.local
       disable denial cluster.local
    }
    loop
    reload
    loadbalance
}

```

## resolv.conf inside a Pod
```text
$ kubectl exec dnsclient -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

```

## Name resolution: short name, namespace-qualified, FQDN
```text
$ kubectl get svc backend -n production
NAME      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
backend   ClusterIP   10.106.39.63   <none>        80/TCP    2s

# getent uses the system resolver, which applies the search path from resolv.conf
# short name from the "default" namespace -> no answer, the Service is in "production"
$ kubectl exec dnsclient -- getent hosts backend; echo exit=$?
command terminated with exit code 2
exit=2

# namespace-qualified: the search path expands it to backend.production.svc.cluster.local
$ kubectl exec dnsclient -- getent hosts backend.production
10.106.39.63      backend.production.svc.cluster.local  backend.production.svc.cluster.local backend.production

# fully qualified
$ kubectl exec dnsclient -- getent hosts backend.production.svc.cluster.local
10.106.39.63      backend.production.svc.cluster.local  backend.production.svc.cluster.local

# the same FQDN queried straight at CoreDNS
$ kubectl exec dnsclient -- nslookup backend.production.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53


Name:	backend.production.svc.cluster.local
Address: 10.106.39.63


# the API server Service, present in every cluster
$ kubectl exec dnsclient -- getent hosts kubernetes.default.svc.cluster.local
10.96.0.1         kubernetes.default.svc.cluster.local  kubernetes.default.svc.cluster.local

# external name, resolved through the CoreDNS forward plugin
$ kubectl exec dnsclient -- getent hosts github.com
20.205.243.166    github.com  github.com

# Pod-to-Service traffic by namespace-qualified name and by FQDN
$ kubectl exec dnsclient -- curl -s -m 5 http://backend.production | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>

$ kubectl exec dnsclient -- curl -s -m 5 http://backend.production.svc.cluster.local | grep -o '<title>.*</title>'
<title>Welcome to nginx!</title>

```

## CoreDNS logs
```text
$ kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
[INFO] 10.244.0.93:41616 - 23160 "AAAA IN backend.production.svc.cluster.local. udp 65 false 1232" NOERROR qr,aa,rd 147 0.000133262s
[INFO] 10.244.0.93:41616 - 23852 "A IN backend.production.svc.cluster.local. udp 65 false 1232" NOERROR qr,aa,rd 106 0.000179474s
[INFO] 10.244.0.93:35552 - 54159 "AAAA IN backend.production.svc.cluster.local.default.svc.cluster.local. udp 91 false 1232" NXDOMAIN qr,aa,rd 173 0.000228878s
[INFO] 10.244.0.93:35552 - 6440 "A IN backend.production.svc.cluster.local.default.svc.cluster.local. udp 91 false 1232" NXDOMAIN qr,aa,rd 173 0.000277461s
[INFO] 10.244.0.93:35552 - 9803 "AAAA IN backend.production.svc.cluster.local.svc.cluster.local. udp 83 false 1232" NXDOMAIN qr,aa,rd 165 0.000135489s
[INFO] 10.244.0.93:35552 - 54630 "A IN backend.production.svc.cluster.local.svc.cluster.local. udp 83 false 1232" NXDOMAIN qr,aa,rd 165 0.000212225s
[INFO] 10.244.0.93:35552 - 55696 "A IN backend.production.svc.cluster.local.cluster.local. udp 79 false 1232" NXDOMAIN qr,aa,rd 161 0.000100617s
[INFO] 10.244.0.93:35552 - 63683 "AAAA IN backend.production.svc.cluster.local.cluster.local. udp 79 false 1232" NXDOMAIN qr,aa,rd 161 0.000238228s
[INFO] 10.244.0.93:35552 - 44704 "AAAA IN backend.production.svc.cluster.local. udp 65 false 1232" NOERROR qr,aa,rd 147 0.00012581s
[INFO] 10.244.0.93:35552 - 41012 "A IN backend.production.svc.cluster.local. udp 65 false 1232" NOERROR qr,aa,rd 106 0.000188598s

```
