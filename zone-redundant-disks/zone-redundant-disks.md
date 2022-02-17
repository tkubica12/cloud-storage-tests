# Zone redundant disks (ZRS disks) in Azure
Purpose of this test is to measure latency increase of ZRS (due to zonal synchronous replication and therefore higher availability) compared to LRS (synchronous replication only within single zone).

Prepare infrastructure including one ZRS and one LRS disk.

```bash
# Create Resource Group
az group create -n zrs -l westeurope

# Create diagnostics storage account (for serial consol access)
export storage=tomasstore$RANDOM
az storage account create -n $storage -g zrs

# Create VM in zone 1
az vm create -n z1 \
    -g zrs \
    --image UbuntuLTS \
    --size Standard_D4as_v4 \
    --boot-diagnostics-storage $storage \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --ephemeral-os-disk 

# Create ZRS disk
az disk create -n zrsdata -g zrs --size-gb 1024 --sku Premium_ZRS 

# Create LRS disk in zone 1
az disk create -n lrsdata -g zrs --size-gb 1024 --sku Premium_LRS --zone 1

# Attach disks to VM
az vm disk attach --vm-name z1 -n zrsdata -g zrs 
az vm disk attach --vm-name z1 -n lrsdata -g zrs 
```

Connect to machine, format and mount disks and download fio configs.

```bash
az serial-console connect -n z1 -g zrs

# Prepare ZRS disk
sudo fdisk /dev/sdc <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdc1
sudo mkdir /zrsdisk
sudo mount /dev/sdc1 /zrsdisk

# Prepare LRS disk
sudo fdisk /dev/sdd <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdd1
sudo mkdir /lrsdisk
sudo mount /dev/sdd1 /lrsdisk

# Download fio configs
git clone https://github.com/tkubica12/cloud-storage-tests.git

# Install fio
sudo apt-get -y update
sudo apt-get install fio -y
```

Run tests and compare ZRS latency with LRS

```bash
cd ./cloud-storage-tests/zone-redundant-disks
sudo fio --runtime 30 zrssyncread.ini   # 4,3 ms
sudo fio --runtime 30 zrssyncwrite.ini  # 3,2 ms
sudo fio --runtime 30 zrsasyncread.ini  # 5140 IOPS
sudo fio --runtime 30 zrsasyncwrite.ini # 5180 IOPS
sudo fio --runtime 30 lrssyncread.ini   # 2,2 ms
sudo fio --runtime 30 lrssyncwrite.ini  # 1,3 ms
sudo fio --runtime 30 lrsasyncread.ini  # 5140 IOPS
sudo fio --runtime 30 lrsasyncwrite.ini # 5140 IOPS
```

Try VM in zone 2

```bash
# Create VM in zone 2
az vm create -n z2 \
    -g zrs \
    --image UbuntuLTS \
    --size Standard_D4as_v4 \
    --boot-diagnostics-storage $storage \
    --zone 2 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --ephemeral-os-disk 

# Try to attach ZRS and LRS disk
az vm disk detach --vm-name z1 -n zrsdata -g zrs 
az vm disk detach --vm-name z1 -n lrsdata -g zrs 
az vm disk attach --vm-name z2 -n zrsdata -g zrs  # SUCCESS: ZRS disk can be attached in any zone
az vm disk attach --vm-name z2 -n lrsdata -g zrs  # FAIL: LRS disk is bound to zone 1

# Connect to VM
az serial-console connect -n z2 -g zrs

# Prepare ZRS disk
sudo fdisk /dev/sdc <<EOF
n
p
1
1


w
EOF

sudo mkdir /zrsdisk   # Do not make FS (this is done already), just mount it
sudo mount /dev/sdc1 /zrsdisk

# Download fio configs
git clone https://github.com/tkubica12/cloud-storage-tests.git

# Install fio
sudo apt-get -y update
sudo apt-get install fio -y

# Run tests and compare with latency in zone 1
cd ./cloud-storage-tests/zone-redundant-disks
sudo fio --runtime 30 zrssyncread.ini   # 2,2 ms
sudo fio --runtime 30 zrssyncwrite.ini  # 3,2 ms
sudo fio --runtime 30 zrsasyncread.ini  # 5180 IOPS
sudo fio --runtime 30 zrsasyncwrite.ini # 5180 IOPS
```

You can repeat test in zone 3 - he are my results:

```bash
sudo fio --runtime 30 zrssyncread.ini   # 3,2 ms
sudo fio --runtime 30 zrssyncwrite.ini  # 4,8 ms
sudo fio --runtime 30 zrsasyncread.ini  # 5180 IOPS
sudo fio --runtime 30 zrsasyncwrite.ini # 5180 IOPS
```