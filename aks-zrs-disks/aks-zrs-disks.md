# AKS with zone-redundant disks and multi-attach to speed up failover
While Azure Disks provide great capabilities for AKS such as good performance to cost ratio (same speed disk is usualy cheaper than same speed NAS), higher performance range (with UltraSSD on top of spectrum) or ability map to Pod as raw device, there are some downsides. It takes quite some time for Azure to detach disks and attach to different VM so rolling upgrades take more significant impact (minutes) and brings more risks and timing issues during node failure. This can be solved by using multi-attach (shared disk) and I/O fencing so disk is already attached to other node making failover quicker. Second limitation of traditional LRS disk is, that it lives only in one availability zone. Should whole zone fail, disk cannot be attached to nodes in different zone (you should rather rely on shared-nothing architecture or tolerate prolonged downtime).

Create AKS with 2 nodes in zone 1 and additional nodepool with 2 nodes spread between zones.

```bash
# Create Resource Group
az group create -n aks -l westeurope

# Create AKS with multi-zone nodepool
az aks create -n aks \
    -g aks \
    --no-ssh-key \
    --node-count 2 \
    --node-vm-size Standard_B2s \
    --zones 1 2 \
    --nodepool-name multizone \
    --nodepool-labels multizone=true

# Add single-zone nodepool
az aks nodepool add -n singlezone \
    -g aks \
    --node-count 2 \
    --node-vm-size Standard_B2s \
    --zones 1 \
    --labels multizone=false \
    --cluster-name aks 

# Get credentials
az aks get-credentials -n aks -g aks --admin --overwrite-

# Configure RBAC for cluster idenity (for later use by CSI driver)
az role assignment create --role Contributor \
  -g mc_aks_aks_westeurope \
  --addignee-object-id $(az identity show -n aks-agentpool -g mc_aks_aks_westeurope --query objectId -o tsv)

# Check nodes and zones
kubectl get nodes -L topology.kubernetes.io/zone -L multizone

: `
NAME                                 STATUS   ROLES   AGE   VERSION   ZONE           MULTIZONE
aks-multizone-20099732-vmss000000    Ready    agent   31m   v1.21.9   westeurope-1   true
aks-multizone-20099732-vmss000001    Ready    agent   31m   v1.21.9   westeurope-2   true
aks-singlezone-13727734-vmss000000   Ready    agent   23m   v1.21.9   westeurope-1   false
aks-singlezone-13727734-vmss000001   Ready    agent   23m   v1.21.9   westeurope-1   false
`
```

Install Azure storage CSI driver v2 (preview in time of writing)

```bash
helm repo add azuredisk-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts

helm install azuredisk-csi-driver-v2 azuredisk-csi-driver/azuredisk-csi-driver \
  --namespace kube-system \
  --version v2.0.0-alpha.1 \
  --values=https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/charts/v2.0.0-alpha.1/azuredisk-csi-driver/side-by-side-values.yaml
```



```bash
kubectl apply -f .

# Cordon node on which singlezonepool-classic is running and measure downtime
pod=$(kubectl get pods -l app=singlezonepool-classic -o jsonpath='{.items[0].metadata.name}')
node=$(kubectl get pod $pod -o=jsonpath='{.spec.nodeName}')
kubectl drain $node --delete-emptydir-data --ignore-daemonsets --  # 146 seconds (out of which 30s is Pod termination grace period)
kubectl uncordon $node

# Cordon node on which multizonepool-classic is running and measure downtime
pod=$(kubectl get pods -l app=multizonepool-classic -o jsonpath='{.items[0].metadata.name}')
node=$(kubectl get pod $pod -o=jsonpath='{.spec.nodeName}')
kubectl drain $node --delete-emptydir-data --ignore-daemonsets --  # Forever! We do not have any other node in the same zone in this static nodepool
kubectl uncordon $node

# Check PVCs for v2 CSI are attached to two nodes
disk=$(kubectl get pvc multizonepool-zrs-shared -o=jsonpath='{.spec.volumeName}')
az disk show -n $disk -g mc_aks_aks_westeurope --query managedByExtended -o tsv

: `
/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/resourceGroups/MC_aks_aks_westeurope/providers/Microsoft.Compute/virtualMachineScaleSets/aks-multizone-20099732-vmss/virtualMachines/aks-multizone-20099732-vmss_1
/subscriptions/a0f4a733-4fce-4d49-b8a8-d30541fc1b45/resourceGroups/MC_aks_aks_westeurope/providers/Microsoft.Compute/virtualMachineScaleSets/aks-multizone-20099732-vmss/virtualMachines/aks-multizone-20099732-vmss_0
`

# Cordon node on which singlezonepool-zrs-shared is running and measure downtime
pod=$(kubectl get pods -l app=singlezonepool-zrs-shared -o jsonpath='{.items[0].metadata.name}')
node=$(kubectl get pod $pod -o=jsonpath='{.spec.nodeName}')
kubectl drain $node --delete-emptydir-data --ignore-daemonsets --  # 64 seconds (out of which 30s is Pod termination grace period)
kubectl uncordon $node

# Cordon node on which multizonepool-zrs-shared is running and measure downtime
pod=$(kubectl get pods -l app=multizonepool-zrs-shared -o jsonpath='{.items[0].metadata.name}')
node=$(kubectl get pod $pod -o=jsonpath='{.spec.nodeName}')
kubectl drain $node --delete-emptydir-data --ignore-daemonsets --  # 72 seconds (out of which 30s is Pod termination grace period)
kubectl uncordon $node

```
