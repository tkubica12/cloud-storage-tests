# Disks in Azure
Measure 3 different performance aspects:
- Latency (measured as single iodepth 4k block synchronous operations)
- IOPS (measured as large iodepth 4k block)
- Throughput (measured as large iodepth 1M block)

Test following block storeage options:
- Standard HDD1 TB
- Standard SSD 1TB
- Premium SSD 1TB
- Ultra SSD 1TB with 20k provisioned IOPS and 300 MB/s provisioned throughput
- Elastic SAN Premium SSD

Prepare infrastructure

```bash
# Create Resource Group
az group create -n disks -l francecentral

# Create Virtual Network
az network vnet create -n disks-vnet -g disks --address-prefix 10.0.0.0/24
az network vnet subnet create -n disks-subnet -g disks --vnet-name disks-vnet --address-prefix 10.0.0.0/24 --service-endpoints "Microsoft.Storage"

# Create VM in zone 1
az vm create -n z1 \
    -g disks \
    --image UbuntuLTS \
    --size Standard_D16dv5 \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --ultra-ssd-enabled \
    --vnet-name disks-vnet \
    --subnet disks-subnet

    --ephemeral-os-disk \
# Create disks
az disk create -n standardhdd   -g disks --size-gb 1024 --sku Standard_LRS      --zone 1
az disk create -n standardssd   -g disks --size-gb 1024 --sku StandardSSD_LRS   --zone 1
az disk create -n premiumssd    -g disks --size-gb 1024 --sku Premium_LRS       --zone 1
az disk create -n premiumssd_v2 -g disks --size-gb 1024 --sku PremiumV2_LRS     --zone 1 --disk-iops-read-write 20000 --disk-mbps-read-write 300
az disk create -n ultrassd      -g disks --size-gb 1024 --sku UltraSSD_LRS      --zone 1 --disk-iops-read-write 20000 --disk-mbps-read-write 300

# Create Elastic SAN
az elastic-san create -n esan \
    -g disks \
    --base-size-tib 1 \
    --extended-capacity-size-tib 0 \
    --sku "{name:Premium_LRS,tier:Premium}" \
    --availability-zones ["1"]

az elastic-san volume-group create --elastic-san-name esan -g disks -n vg1 \
  --network-acls "{virtualNetworkRules:[{id:$(az network vnet subnet show -n disks-subnet -g disks --vnet-name disks-vnet --query id -o tsv),action:Allow}]}"

az elastic-san volume-group update --elastic-san-name esan -g disks -n vg1 \
  --network-acls '{"virtualNetworkRules":[{"id":"'$(az network vnet subnet show -n disks-subnet -g disks --vnet-name disks-vnet --query id -o tsv)'","action":"Allow"}]}"'

az elastic-san volume create --elastic-san-name esan -g disks -v vg1 -n vol1 --size-gib 1000

# Attach disks to VM
az vm disk attach --vm-name z1 -n standardhdd -g disks 
az vm disk attach --vm-name z1 -n standardssd -g disks 
az vm disk attach --vm-name z1 -n premiumssd -g disks 
az vm disk attach --vm-name z1 -n premiumssd_v2 -g disks 
az vm disk attach --vm-name z1 -n ultrassd -g disks 

# Create eSAN (currently only in France Central)
az elastic-san create -n esan \
    -g disks \
    -l francecentral \
    --base-size-tib 1 \
    --extended-capacity-size-tib 0 \
    --sku "{name:Premium_LRS,tier:Premium}"

```

Download fio configs, mount disks and run tests.

```bash
az serial-console connect -n z1 -g disks

# Clone repo
git clone https://github.com/tkubica12/cloud-storage-tests.git

# Provision and mount disks
sudo bash ./cloud-storage-tests/disks/provision.sh

# Mount eSAN via iSCSI
sudo iscsiadm -m node --target iqn.2022-10.net.windows.core.blob.ElasticSan.es-lxn2jmefjsw0:vol1 --portal es-lxn2jmefjsw0.z36.blob.storage.azure.net:3260 -o new
sudo iscsiadm -m node --targetname iqn.2022-10.net.windows.core.blob.ElasticSan.es-lxn2jmefjsw0:vol1 -p es-lxn2jmefjsw0.z36.blob.storage.azure.net:3260 -l

sudo fdisk /dev/sdc <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdc1
sudo mkdir /esan
sudo mount /dev/sdc1 /esan

# Install fio
sudo apt update
sudo apt install fio -y

# Go to configs folder
cd ./cloud-storage-tests/disks

# Latency read
sudo fio --runtime 30 sync-r-standardhdd.ini    #  3-20 ms when repeated multiple times
sudo fio --runtime 30 sync-r-standardssd.ini    #  2.3 ms
sudo fio --runtime 30 sync-r-premiumssd.ini     #  2.4 ms
sudo fio --runtime 30 sync-r-premiumssd_v2.ini  #  0.7 ms
sudo fio --runtime 30 sync-r-ultrassd.ini       #  0.4 ms

# Latency write
sudo fio --runtime 30 sync-w-standardhdd.ini    #  2.9 ms
sudo fio --runtime 30 sync-w-standardssd.ini    #  1.3 ms
sudo fio --runtime 30 sync-w-premiumssd.ini     #  1.3 ms
sudo fio --runtime 30 sync-w-premiumssd_v2.ini  #  0.7 ms
sudo fio --runtime 30 sync-w-ultrassd.ini       #  0.4 ms

# IOPS read
sudo fio --runtime 30 async-r-standardhdd.ini    #   561 IOPS (expected 500 IOPS)
sudo fio --runtime 30 async-r-standardssd.ini    #  1001 IOPS (this is burst on 1TB SKU - non-bursted performance is 500 IOPS)
sudo fio --runtime 30 async-r-premiumssd.ini     #  5210 IOPS (expected 5000 IOPS)
sudo fio --runtime 30 async-r-premiumssd_v2.ini  # 20400 IOPS (20k provisioned)
sudo fio --runtime 30 async-r-ultrassd.ini       # 20400 IOPS (20k provisioned)

# IOPS write
sudo fio --runtime 30 async-w-standardhdd.ini    #   560 IOPS (expected 500 IOPS)
sudo fio --runtime 30 async-w-standardssd.ini    #  1000 IOPS (this is burst on 1TB SKU - non-bursted performance is 500 IOPS)
sudo fio --runtime 30 async-w-premiumssd.ini     #  5180 IOPS (expected 5000 IOPS)
sudo fio --runtime 30 async-w-premiumssd_v2.ini  # 20400 IOPS (20k provisioned)
sudo fio --runtime 30 async-w-ultrassd.ini       # 20400 IOPS (20k provisioned)

# Throughput
sudo fio --runtime 30 large-r-standardhdd.ini    #   97 MiB/s (expected 60 MiB/s)
sudo fio --runtime 30 large-r-standardssd.ini    #  202 MiB/s (expected 150 MiB/s burst on 1TB SKU - non-bursted performance expected as 60 MiB/s)
sudo fio --runtime 30 large-r-premiumssd.ini     #  198 MiB/s (expected 200 MiB/s)
sudo fio --runtime 30 large-r-premiumssd_v2.ini  #  320 MiB/s (300 MiB/s provisioned)
sudo fio --runtime 30 large-r-ultrassd.ini       #  320 MiB/s (300 MiB/s provisioned)
```