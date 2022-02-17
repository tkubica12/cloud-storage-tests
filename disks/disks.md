# Disks in Azure
Measure 3 different performance aspects:
- Latency (measured as single iodepth 4k block synchronous operations)
- IOPS (measured as large iodepth 4k block)
- Throughput (measured as large iodepth 1M block)

Test following disk options:
- Local temp disk
- Standard HDD1 TB
- Standard SSD 1TB
- Premium SSD 1TB
- Ultra SSD 1TB with 20k provisioned IOPS and 300 MB/s provisioned throughput
- Local NVMe (L-series VM) - TBD

Prepare infrastructure

```bash
# Create Resource Group
az group create -n disks -l westeurope

# Create diagnostics storage account (for serial consol access)
export storage=tomasstore$RANDOM
az storage account create -n $storage -g disks

# Create VM in zone 1
az vm create -n z1 \
    -g disks \
    --image UbuntuLTS \
    --size Standard_D16as_v4 \
    --boot-diagnostics-storage $storage \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --ephemeral-os-disk \
    --ultra-ssd-enabled

# Create disks
az disk create -n standardhdd   -g disks --size-gb 1024 --sku Standard_LRS --zone 1
az disk create -n standardssd   -g disks --size-gb 1024 --sku StandardSSD_LRS --zone 1
az disk create -n premiumssd    -g disks --size-gb 1024 --sku Premium_LRS --zone 1
az disk create -n ultrassd      -g disks --size-gb 1024 --sku UltraSSD_LRS --zone 1 --disk-iops-read-write 20000 --disk-mbps-read-write 300

# Attach disks to VM
az vm disk attach --vm-name z1 -n standardhdd -g disks 
az vm disk attach --vm-name z1 -n standardssd -g disks 
az vm disk attach --vm-name z1 -n premiumssd -g disks 
az vm disk attach --vm-name z1 -n ultrassd -g disks 
```

Download fio configs, mount disks and run tests.

```bash
az serial-console connect -n z1 -g disks

# Clone repo
git clone https://github.com/tkubica12/cloud-storage-tests.git

sudo bash ./cloud-storage-tests/disks/provision.sh

```