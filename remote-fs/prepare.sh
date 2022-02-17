# Create VM
az group create -n perf -l westeurope
az network vnet create -n vnet -g perf --address-prefix 10.0.0.0/16
az network vnet subnet create --vnet-name vnet -g perf --address-prefix 10.0.0.0/24 -n default --service-endpoints Microsoft.Storage
az network vnet subnet create --vnet-name vnet -g perf --address-prefix 10.0.1.0/24 -n netapp --delegations Microsoft.NetApp/volumes
az network nsg create -n mynsg -g perf 
az network nsg rule create -n ssh -g perf --nsg-name mynsg --priority 120 --source-address-prefixes $(curl ifconfig.io) --destination-port-ranges 22 
az vm create -n perfvm \
    -g perf \
    --image Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest \
    --size Standard_D8as_v4 \
    --admin-username tomas \
    --ssh-key-values ~/.ssh/id_rsa.pub \
    --nsg mynsg \
    --public-ip-address perfvm

# Create storages
## Create accounts
echo export premiumFilesName=tomfilespremium$RANDOM > .env
echo export standardStorageName=tomstandard$RANDOM >> .env
echo export premiumBlobStorageName=tompremium$RANDOM >> .env
source .env

az storage account create -n $premiumFilesName -g perf --https-only false --sku Premium_LRS --kind FileStorage --subnet default --vnet-name vnet --action Allow --default-action Deny
az storage account create -n $standardStorageName -g perf --https-only false --sku Standard_LRS --subnet default --vnet-name vnet --action Allow --default-action Deny --enable-nfs-v3 --hns  
az storage account create -n $premiumBlobStorageName -g perf --https-only --sku Premium_LRS --kind BlockBlobStorage --subnet default --vnet-name vnet --action Allow --default-action Deny --enable-nfs-v3 --hns 
az netappfiles account create -n mynetapp -g perf -l westeurope

az storage account network-rule add -g perf --account-name $premiumFilesName --ip-address $(curl ipconfig.io)
az storage account network-rule add -g perf --account-name $standardStorageName --ip-address $(curl ipconfig.io)
az storage account network-rule add -g perf --account-name $premiumBlobStorageName --ip-address $(curl ipconfig.io)

echo export standardStoragekey=$(az storage account keys list -n $standardStorageName --query [0].value -o tsv) >> .env

## Create shares/volumes
az storage share-rm create --storage-account $premiumFilesName -n smallpremium --quota 100 --enabled-protocol NFS
az storage share-rm create --storage-account $premiumFilesName -n largepremium --quota 4000 --enabled-protocol NFS

standardStorageConnection=$(az storage account show-connection-string -g perf -n $standardStorageName --query connectionString -o tsv)
az storage share create --account-name $standardStorageName -n standard --quota 100 --connection-string $standardStorageConnection

az storage fs create -n blobstandard --connection-string $standardStorageConnection

premiumBlobStorageConnection=$(az storage account show-connection-string -g perf -n $premiumBlobStorageName --query connectionString -o tsv)
az storage fs create -n blobpremium --connection-string $premiumBlobStorageConnection

az netappfiles pool create -g perf -a mynetapp -n netappstandard -l westeurope --size 4 --service-level standard
az netappfiles pool create -g perf -a mynetapp -n netapppremium -l westeurope --size 4 --service-level premium
az netappfiles pool create -g perf -a mynetapp -n netappultra -l westeurope --size 4 --service-level ultra

az netappfiles volume create -g perf \
    -a mynetapp \
    --file-path netappstandard \
    -n netappstandard \
    -p netappstandard \
    --vnet vnet \
    --subnet netapp \
    --protocol-types NFSv4.1 \
    -l westeurope \
    --usage-threshold 4000 \
    --allowed-clients 10.0.0.0/8 \
    --rule-index 1 \
    --unix-read-write

az netappfiles volume create -g perf \
    -a mynetapp \
    --file-path netapppremium \
    -n netapppremium \
    -p netapppremium \
    --vnet vnet \
    --subnet netapp \
    --protocol-types NFSv4.1 \
    -l westeurope \
    --usage-threshold 4000 \
    --allowed-clients 10.0.0.0/8 \
    --rule-index 1 \
    --unix-read-write

az netappfiles volume create -g perf \
    -a mynetapp \
    --file-path netappultra \
    -n netappultra \
    -p netappultra \
    --vnet vnet \
    --subnet netapp \
    --protocol-types NFSv4.1 \
    -l westeurope \
    --usage-threshold 4000 \
    --allowed-clients 10.0.0.0/8 \
    --rule-index 1 \
    --unix-read-write


