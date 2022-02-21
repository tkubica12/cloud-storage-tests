# Local storage with AKS tests
Use case - temp storage for workloads or fast local storage for data workloads that maintain data resiliency in database layer.

Key challanges and findings:
- EmptyDir supports storage limit, but kills process. Also it is hosted on main OS disk which might cause performance issues when overloaded, can have small capacity (especially when ephemeral drives are used) - cannot leverage other local disks such as temp disk or fast big NVMe storage such as with Azure L-series VMs.
- HostPath can leverage different locations such as NVMe, but requires pre-provisioning of mounting, FS and directory structures (this can be automated with Local Path Provisioner). Nevertheless it does not suport any size limits, can be security issue (policies such as Azure Policy to prevent dangerous to be configured is highly recommended), users can simply do mistake and connect to data of someone else etc.
- Local Persistent Volume with manual provisioning (preparation of mounts and folders + pre-creation of Persistent Volumes) is safer choice, but is harder to manage and does not support size limits.
- Local Persistent Volume with provisioner allows for new devices to be automatically mounted and added as Persistent Volume. This is easier from operations perspective, but does not solve slicing of mounted device (it is OK, if you have one workload on it anyway such as nodes dedicated to storage intensive replicated workload) and do not enforce size limits.
- NativeStor (operator on top of TopoLVM) provides true size limits (storage-enforced, no killing of container), full automation and dynamic provisioning. It is great choice, but you are dependent on OSS projects which might bring bugs and supportability issues to your production environment.

**Note: using local storage in cloud environments such as AKS is problematic, because when AKS upgrades nodes it does it in immutable way basicaly replacing nodes with fresh ones with newer OS or Kubernetes version. Therefore data loss is more common than in traditional on-prem environment with long-lived "snowflake-style" mutable nodes. Make sure your workload can handle this well and test for it as data recovery in cluster might be expensive operation and you end up rather using remote resillient storage for it anyway.**

# Prepare cluster

```bash
# Create Resource Group 
az group create -n akslocalstorage -l westeurope

# Create AKS clusters
```bash
az aks create -g akslocalstorage -n akslocalstorage -c 2 -s Standard_L8s_v2 -x -k 1.22.2 --no-wait
az aks get-credentials -g akslocalstorage -n akslocalstorage --admin
```

# EmptyDir

```bash
cd emptyDir
```

## Size limit test
```bash
kubectl apply -f test.yaml
pod=$(kubectl get pods -l app=test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -ti $pod -- bash
    dd if=/dev/zero of=/path/file1 count=8000 bs=1048576
    dd if=/dev/zero of=/path/file2 count=8000 bs=1048576

# Pod got evicted - data is lost, process terminated.

kubectl delete pod $pod
pod=$(kubectl get pods -l app=test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -ti $pod -- ls /path

kubectl delete -f test.yaml
```

## Drain node test
```bash
kubectl apply -f test.yaml
pod=$(kubectl get pods -l app=test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -ti $pod -- ls /path
node=$(kubectl get pod $pod -o=jsonpath='{.spec.nodeName}')
kubectl drain $node --delete-emptydir-data --ignore-daemonsets --force

# Pod got evicted and started on second node - data lost.

kubectl uncordon $node

kubectl delete -f test.yaml
```

# hostPath
```bash
cd hostaPath
```

## DaemonSet to provision NVMe device
```bash
kubectl apply -f provisionStorage.yaml
```

## Drain node test
```bash
kubectl apply -f test.yaml
pod=$(kubectl get pods -l app=test -o jsonpath='{.items[0].metadata.name}')
kubectl exec -ti $pod -- ls /path
node=$(kubectl get pod $pod -o=jsonpath='{.spec.nodeName}')
kubectl drain $node --delete-emptydir-data --ignore-daemonsets --force

# Pod got evicted and started on second node - data lost. Also folders are not cleaned up, so you can see different data than expected!

kubectl uncordon $node
kubectl delete -f test.yaml
```

# Local Persistent Volume 
```bash
cd LocalPersistentVolumeManual
kubectl apply -f provisionStorage.yaml
kubectl apply -f storageClass.yaml
kubectl apply -f storageClass.yaml
kubectl apply -f volumes.yaml

# We need to create PVs that must be bounded to individual node
node1=$(kubectl get nodes -o=jsonpath='{.items[0].metadata.name}')
node2=$(kubectl get nodes -o=jsonpath='{.items[1].metadata.name}')
sed s/node1/$node1/g volumes.yaml | sed s/node2/$node2/g | kubectl apply -f -

kubectl apply -f test.yaml

```

Note when node names change (which can happen after every AKS upgrade) you need to reprovision PVs.

# Local Persistent Volume with provisioner
```bash
cd LocalPersistentVolumeProvisioner
kubectl apply -f storageClass.yaml
kubectl apply -f provisioner.yaml
kubectl get pv    # PVs got created for you - one for every discovered device

kubectl apply -f test.yaml
```

# NativeStor (TopoLVM)
```bash
cd NativeStor
```

Deploy NativeStor operator and settings.

```bash
kubectl apply -f https://raw.githubusercontent.com/alauda/nativestor/main/deploy/example/operator.yaml
kubectl apply -f https://raw.githubusercontent.com/alauda/nativestor/main/deploy/example/setting.yaml
```

Apply topoLVM configuration. In our case we want to operate only on nvme device (you can also limit nodes eg. if you have specific nodepool with Azure L-series VMs)

```bash
kubectl apply -f topoLvm.yaml
```

We can see, that on nodes Physical Volume object is visible.

```code
root@aks-nodepool1-19673502-vmss000006:/# pvdisplay
  --- Physical volume ---
  PV Name               /dev/nvme0n1
  VG Name               nvme
  PV Size               <1.75 TiB / not usable <4.34 MiB
  Allocatable           yes
  PE Size               4.00 MiB
  Total PE              457854
  Free PE               457598
  Allocated PE          256
  PV UUID               LLkkIs-wguA-Y1JW-kMq8-Nion-ySiH-ewcmyl
```

Create storage class and apply workload with dynamic volume provisioning.

```bash
kubectl apply -f storageClass.yaml
kubectl apply -f test.yaml
```

On nodes we can see solution has created Logical Volume for our Persistent Volume.

```
root@aks-nodepool1-19673502-vmss000006:/# lvdisplay
  --- Logical volume ---
  LV Path                /dev/nvme/860f2f01-0dc3-484f-bb3b-3268c9b90fd6
  LV Name                860f2f01-0dc3-484f-bb3b-3268c9b90fd6
  VG Name                nvme
  LV UUID                bsde3b-cPgk-6FKc-cyKG-bzZo-uOGJ-CjvnHc
  LV Write Access        read/write
  LV Creation host, time aks-nodepool1-19673502-vmss000006, 2022-02-08 06:57:02 +0000
  LV Status              available
  # open                 1
  LV Size                1.00 GiB
  Current LE             256
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:0

```

## Test size limits

```bash
kubectl exec mystatefulset-0 -ti  -- bash
ls /path
    dd if=/dev/zero of=/path/file1 count=8000 bs=1048576
    dd: error writing '/path/file1': No space left on device
```

Node limit is enforced on storage level - no container kill like with EmptyDir or no control like with hostPath or LPV.