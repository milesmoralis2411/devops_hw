# Evidence — Kubernetes volumes

Executed on minikube v1.39.0 / Kubernetes v1.37.0 (containerd), metrics-server v0.9.0, 2026-10-07. Output is verbatim.

## Volumes

### emptyDir - shared between two containers, gone with the Pod
```text
$ kubectl apply -f 01-kubernetes-volumes/01-emptydir.yaml
pod/emptydir-demo created

$ kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=120s
pod/emptydir-demo condition met

# the reader container sees what the writer container wrote
$ kubectl exec emptydir-demo -c reader -- cat /cache/out.log
Wed Oct  7 15:24:10 UTC 2026
Wed Oct  7 15:24:15 UTC 2026
Wed Oct  7 15:24:20 UTC 2026

$ kubectl get pod emptydir-demo -o jsonpath='{.spec.volumes}'; echo
[{"emptyDir":{},"name":"cache"},{"name":"kube-api-access-6bfqt","projected":{"defaultMode":420,"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"items":[{"key":"ca.crt","path":"ca.crt"}],"name":"kube-root-ca.crt"}},{"downwardAPI":{"items":[{"fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"},"path":"namespace"}]}}]}}]

# delete and recreate the Pod: the data does not survive
$ kubectl delete pod emptydir-demo
pod "emptydir-demo" deleted from default namespace

$ kubectl apply -f 01-kubernetes-volumes/01-emptydir.yaml
pod/emptydir-demo created

$ kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=120s
pod/emptydir-demo condition met

$ kubectl exec emptydir-demo -c reader -- sh -c 'wc -l < /cache/out.log'
1

```

### hostPath - reading the node filesystem
```text
$ minikube ssh -- 'echo written-on-the-node > /tmp/from-node.txt'

$ kubectl apply -f 01-kubernetes-volumes/02-hostpath.yaml
pod/hostpath-demo created

$ kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=120s
pod/hostpath-demo condition met

$ kubectl exec hostpath-demo -- cat /host-tmp/from-node.txt
written-on-the-node

# mounted read-only, so writes are refused
$ kubectl exec hostpath-demo -- sh -c 'echo x > /host-tmp/nope.txt'
sh: can't create /host-tmp/nope.txt: Read-only file system
command terminated with exit code 1

```

### PersistentVolume + PersistentVolumeClaim (static)
```text
$ kubectl apply -f 01-kubernetes-volumes/03-pv-pvc.yaml
persistentvolume/pv-demo created
persistentvolumeclaim/pvc-demo created
pod/pvc-consumer created

$ kubectl wait --for=condition=Ready pod/pvc-consumer --timeout=120s
pod/pvc-consumer condition met

$ kubectl get pv pv-demo
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM              STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-demo   1Gi        RWO            Retain           Bound    default/pvc-demo   manual         <unset>                          15s

$ kubectl get pvc pvc-demo
NAME       STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-demo   Bound    pv-demo   1Gi        RWO            manual         <unset>                 15s

$ kubectl exec pvc-consumer -- cat /data/hello.txt
written to the PV

# delete the Pod, start a new one on the same claim: the data is still there
$ kubectl delete pod pvc-consumer
pod "pvc-consumer" deleted from default namespace

$ kubectl wait --for=condition=Ready pod/pvc-consumer-2 --timeout=120s
pod/pvc-consumer-2 condition met

$ kubectl exec pvc-consumer-2 -- cat /data/hello.txt
written to the PV

# Retain policy: deleting the claim releases the PV but keeps it
$ kubectl delete pvc pvc-demo
persistentvolumeclaim "pvc-demo" deleted from default namespace

$ kubectl get pv pv-demo
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM              STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-demo   1Gi        RWO            Retain           Released   default/pvc-demo   manual         <unset>                          81s

```

### StorageClass + dynamic provisioning
```text
$ kubectl get storageclass
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  24m

$ kubectl get pv
NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM              STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-demo   1Gi        RWO            Retain           Released   default/pvc-demo   manual         <unset>                          81s

$ kubectl apply -f 01-kubernetes-volumes/04-dynamic-provisioning.yaml
persistentvolumeclaim/pvc-dynamic created
pod/dynamic-consumer created

$ kubectl wait --for=condition=Ready pod/dynamic-consumer --timeout=120s
pod/dynamic-consumer condition met

# no PV was written by hand - the provisioner created one
$ kubectl get pvc pvc-dynamic
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
pvc-dynamic   Bound    pvc-3310386a-fad4-43ce-a17d-4f9fc9d5b0c1   500Mi      RWO            standard       <unset>                 1s

$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                 STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pv-demo                                    1Gi        RWO            Retain           Released   default/pvc-demo      manual         <unset>                          82s
pvc-3310386a-fad4-43ce-a17d-4f9fc9d5b0c1   500Mi      RWO            Delete           Bound      default/pvc-dynamic   standard       <unset>                          1s

$ kubectl exec dynamic-consumer -- cat /data/hello.txt
dynamically provisioned

$ kubectl describe pvc pvc-dynamic | sed -n '/^Events:/,$p'
Events:
  Type    Reason                 Age   From                                                                    Message
  ----    ------                 ----  ----                                                                    -------
  Normal  ExternalProvisioning   2s    persistentvolume-controller                                             Waiting for a volume to be created either by the external provisioner 'k8s.io/minikube-hostpath' or manually by the system administrator. If volume creation is delayed, please verify that the provisioner is running and correctly registered.
  Normal  Provisioning           2s    k8s.io/minikube-hostpath_minikube_1ad3b629-a096-4a9b-8d0e-d3eafac2189f  External provisioner is provisioning volume for claim "default/pvc-dynamic"
  Normal  ProvisioningSucceeded  2s    k8s.io/minikube-hostpath_minikube_1ad3b629-a096-4a9b-8d0e-d3eafac2189f  Successfully provisioned volume pvc-3310386a-fad4-43ce-a17d-4f9fc9d5b0c1

```

