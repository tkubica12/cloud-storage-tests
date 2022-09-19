# Disks in Azure
Measure 3 different performance aspects:
- Latency (measured as single iodepth 4k block synchronous operations)
- IOPS (measured as large iodepth 4k block)
- Throughput (measured as large iodepth 1M block)

Test following disk options:
- Standard HDD1 TB
- Standard SSD 1TB
- Premium SSD 1TB
- Ultra SSD 1TB with 20k provisioned IOPS and 300 MB/s provisioned throughput

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
    --size Standard_D16ds_v5 \
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
az disk create -n standardhdd   -g disks --size-gb 1024 --sku Standard_LRS      --zone 1
az disk create -n standardssd   -g disks --size-gb 1024 --sku StandardSSD_LRS   --zone 1
az disk create -n premiumssd    -g disks --size-gb 1024 --sku Premium_LRS       --zone 1
az disk create -n premiumssd_v2 -g disks --size-gb 1024 --sku PremiumV2_LRS     --zone 1 --disk-iops-read-write 20000 --disk-mbps-read-write 300
az disk create -n ultrassd      -g disks --size-gb 1024 --sku UltraSSD_LRS      --zone 1 --disk-iops-read-write 20000 --disk-mbps-read-write 300

# Attach disks to VM
az vm disk attach --vm-name z1 -n standardhdd -g disks 
az vm disk attach --vm-name z1 -n standardssd -g disks 
az vm disk attach --vm-name z1 -n premiumssd -g disks 
az vm disk attach --vm-name z1 -n premiumssd_v2 -g disks 
az vm disk attach --vm-name z1 -n ultrassd -g disks 
```

Download fio configs, mount disks and run tests.

```bash
az serial-console connect -n z1 -g disks

# Clone repo
git clone https://github.com/tkubica12/cloud-storage-tests.git

# Provision and mount disks
sudo bash ./cloud-storage-tests/disks/provision.sh

# Install fio
sudo apt update
sudo apt install fio -y

# Go to configs folder
cd ./cloud-storage-tests/disks

# Latency read
sudo fio --runtime 30 sync-r-standardhdd.ini    #  3-20 ms when repeated multiple times
sudo fio --runtime 30 sync-r-standardssd.ini    #  2.3 ms
sudo fio --runtime 30 sync-r-premiumssd.ini     #  2.4 ms
sudo fio --runtime 30 sync-r-premiumssd_v2.ini  #  x ms
sudo fio --runtime 30 sync-r-ultrassd.ini       #  0.4 ms

# Latency write
sudo fio --runtime 30 sync-w-standardhdd.ini    #  2.9 ms
sudo fio --runtime 30 sync-w-standardssd.ini    #  1.3 ms
sudo fio --runtime 30 sync-w-premiumssd.ini     #  1.3 ms
sudo fio --runtime 30 sync-w-premiumssd_v2.ini  #  x ms
sudo fio --runtime 30 sync-w-ultrassd.ini       #  0.4 ms

# IOPS read
sudo fio --runtime 30 async-r-standardhdd.ini    #   561 IOPS (expected 500 IOPS)
sudo fio --runtime 30 async-r-standardssd.ini    #  1001 IOPS (this is burst on 1TB SKU - non-bursted performance is 500 IOPS)
sudo fio --runtime 30 async-r-premiumssd.ini     #  5210 IOPS (expected 5000 IOPS)
sudo fio --runtime 30 async-r-premiumssd_v2.ini  #  x IOPS (20k provisioned)
sudo fio --runtime 30 async-r-ultrassd.ini       # 21800 IOPS (20k provisioned)

# IOPS write
sudo fio --runtime 30 async-w-standardhdd.ini    #   560 IOPS (expected 500 IOPS)
sudo fio --runtime 30 async-w-standardssd.ini    #  1000 IOPS (this is burst on 1TB SKU - non-bursted performance is 500 IOPS)
sudo fio --runtime 30 async-w-premiumssd.ini     #  5180 IOPS (expected 5000 IOPS)
sudo fio --runtime 30 async-w-premiumssd_v2.ini  #  x IOPS (20k provisioned)
sudo fio --runtime 30 async-w-ultrassd.ini       # 22400 IOPS (20k provisioned)

# Throughput
sudo fio --runtime 30 large-r-standardhdd.ini    #   97 MiB/s (expected 60 MiB/s)
sudo fio --runtime 30 large-r-standardssd.ini    #  202 MiB/s (expected 150 MiB/s burst on 1TB SKU - non-bursted performance expected as 60 MiB/s)
sudo fio --runtime 30 large-r-premiumssd.ini     #  198 MiB/s (expected 200 MiB/s)
sudo fio --runtime 30 large-r-premiumssd_v2.ini  #  x MiB/s (300 MiB/s provisioned)
sudo fio --runtime 30 large-r-ultrassd.ini       #  320 MiB/s (300 MiB/s provisioned)
```