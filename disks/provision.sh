#!/bin/bash

# Prepare and mount Standard HDD
sudo fdisk /dev/sdc <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdc1
sudo mkdir /standardhdd
sudo mount /dev/sdc1 /standardhdd

# Prepare and mount Standard SSD
sudo fdisk /dev/sdd <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdd1
sudo mkdir /standardssd
sudo mount /dev/sdd1 /standardssd

# Prepare and mount Premium SSD
sudo fdisk /dev/sde <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sde1
sudo mkdir /premiumssd
sudo mount /dev/sde1 /premiumssd

# Prepare and mount Ultra SSD
sudo fdisk /dev/sdf <<EOF
n
p
1
1


w
EOF
sudo mkfs.ext4 /dev/sdf1
sudo mkdir /ultrassd
sudo mount /dev/sdf1 /ultrassd