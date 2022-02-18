# Shared disks
Purpose if this demo is to test shared block disk feature in Azure by connecting disk to multiple VMs and use SCSI reservations to orchestrate access to device. Note reservations work on block device level, not on file system level (so you can implement any FS or even no FS at all) - but for purpose of this demo we will do writes to file system which requires remount to see new content etc. In real life SCSI reservation is implementation detail of some clustering software that does coordination for you.

Prepare infrastructure, disk and attach to two VMs.

```bash
# Create Resource Group
az group create -n shareddisk -l westeurope

# Create diagnostics storage account (for serial consol access)
export storage=tomasstore$RANDOM
az storage account create -n $storage -g shareddisk

# Create VNET
az network vnet create -n shareddisknet -g shareddisk --address-prefixes 10.0.0.0/16 --subnet-name default --subnet-prefixes 10.0.0.0/24

# Create VM in zone 1
az vm create -n z1 \
    -g shareddisk \
    --image UbuntuLTS \
    --size Standard_D2as_v4 \
    --boot-diagnostics-storage $storage \
    --zone 1 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --ephemeral-os-disk \
    --vnet-name shareddisknet \
    --subnet default

# Create VM in zone 2
az vm create -n z2 \
    -g shareddisk \
    --image UbuntuLTS \
    --size Standard_D2as_v4 \
    --boot-diagnostics-storage $storage \
    --zone 2 \
    --admin-username tomas \
    --admin-password Azure12345678 \
    --authentication-type password \
    --nsg "" \
    --public-ip-address "" \
    --ephemeral-os-disk \
    --vnet-name shareddisknet \
    --subnet default

# Create disk
az disk create -n shareddisk -g shareddisk --size-gb 32 --sku Premium_ZRS --max-shares 2

# Attach disk to VM
az vm disk attach --vm-name z1 -n shareddisk -g shareddisk 
az vm disk attach --vm-name z2 -n shareddisk -g shareddisk 
```

On z1 reserve disk for writing, create partition, file system, mount and write some file.

```bash
# Connect to z1
az serial-console connect -n z1 -g shareddisk

# Install SCSI utils
sudo apt update
sudo apt install sg3-utils -y

# Make registration and reservation
sudo sg_persist /dev/sdc  # No reservation keys exist
sudo sg_persist --out --register --param-sark=abc123 /dev/sdc  # Register key abc123
sudo sg_persist --out --reserve --param-rk=abc123 --prout-type=7 /dev/sdc  # Reserve disk for writing
sudo sg_persist -r /dev/sdc  # Check reservation

# Create partition, file system, mount and write data
sudo fdisk /dev/sdc <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdc1
sudo mkdir /shareddisk
sudo mount /dev/sdc1 /shareddisk
sudo touch /shareddisk/z1.txt
```

Go to z2 and try to read vs. write

```bash
# Connect to z1
az serial-console connect -n z2 -g shareddisk

# Install SCSI utils
sudo apt update
sudo apt install sg3-utils -y

# Check SCSI reservation
sudo sg_persist /dev/sdc 
sudo sg_persist -r /dev/sdc  # Resource is reservd
sudo sg_persist --out --reserve --param-rk=abc123 --prout-type=7 /dev/sdc  # FAIL, write access is reserved for z1

# Try to mount and read
sudo mkdir /shareddisk
sudo mount -o ro /dev/sdc1 /shareddisk   # FAIL, z2 is not registered

: `
[46305.386143] blk_update_request: I/O error, dev sdc, sector 10536 op 0x1:(WRITE) flags 0x800 phys_seg 1 prio class 0
[46305.393763] Buffer I/O error on dev sdc1, logical block 1061, lost async page write
[46305.398541] blk_update_request: I/O error, dev sdc, sector 10408 op 0x1:(WRITE) flags 0x800 phys_seg 1 prio class 0
[46305.402387] Buffer I/O error on dev sdc1, logical block 1045, lost async page write
[46305.502572] blk_update_request: I/O error, dev sdc, sector 2048 op 0x1:(WRITE) flags 0x800 phys_seg 5 prio class 0
[46305.506451] Buffer I/O error on dev sdc1, logical block 0, lost async page write
[46305.513296] Buffer I/O error on dev sdc1, logical block 1, lost async page write
[46305.518111] Buffer I/O error on dev sdc1, logical block 2, lost async page write
[46305.523047] Buffer I/O error on dev sdc1, logical block 3, lost async page write
[46305.528296] Buffer I/O error on dev sdc1, logical block 4, lost async page write
[46305.532626] blk_update_request: I/O error, dev sdc, sector 76072 op 0x1:(WRITE) flags 0x800 phys_seg 1 prio class 0
[46305.532745] Buffer I/O error on dev sdc1, logical block 9253, lost async page write
[46305.549268] EXT4-fs (sdc1): error loading journal
`

# Make SCSI registration
sudo sg_persist --out --register --param-sark=abc123 /dev/sdc  # Register key abc123

# Try to mount again and rad
sudo mount -o ro /dev/sdc1 /shareddisk   # SUCCESS
sudo ls /shareddisk   # read works

# Remount as read/write and try to write
sudo umount /shareddisk
sudo mount /dev/sdc1 /shareddisk
sudo touch /shareddisk/z2.txt   # Write will eventually fail

: `
[46412.758813] sd 3:0:0:0: [sdc] tag#43 FAILED Result: hostbyte=DID_ERROR driverbyte=DRIVER_OK
[46412.758813] sd 3:0:0:0: [sdc] tag#43 CDB: Write(10) 2a 00 00 01 29 28 00 00 08 00
[46412.758813] blk_update_request: I/O error, dev sdc, sector 76072 op 0x1:(WRITE) flags 0x800 phys_seg 1 prio class 0
[46412.762383] Buffer I/O error on dev sdc1, logical block 9253, lost async page write
[46412.773441] JBD2: recovery failed[46412.773446] EXT4-fs (sdc1): error loading journal
`
```

Go back to z1 and release write lock.

```bash
# Make sure z1 was not able to write
sudo ls /shareddisk

# Release write lock
sudo sg_persist --out --release --param-rk=abc123 --prout-type=7 /dev/sdc
sudo sg_persist -r /dev/sdc  # Check reservation
```

Go back to z2 and obtain write lock.

```bash
# Unmount
sudo umount /shareddisk

# Make reservation
sudo sg_persist --out --reserve --param-rk=abc123 --prout-type=7 /dev/sdc  # Reserve disk for writing

# Mount
sudo mount /dev/sdc1 /shareddisk
sudo touch /shareddisk/z2-B.txt   # Write will eventually fail
```
