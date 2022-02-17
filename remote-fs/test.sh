# Get VM IP
ip=$(az network public-ip show -n perfvm -g perf --query ipAddress -o tsv)

# Copy Files over
scp *.ini tomas@$ip:
scp .env tomas@$ip:

# Connect to VM
ssh tomas@$ip

# Prepare and run tests
## Install tools
sudo apt-get -y update
sudo apt-get install nfs-common unzip fio -y
wget https://github.com/distributed-system-analysis/smallfile/archive/refs/tags/v1.0.1.zip
unzip v1.0.1.zip

## Mount
### Mount Azure Files premium
sudo mkdir -p /mount/smallpremium
sudo mount -t nfs $premiumFilesName.file.core.windows.net:/$premiumFilesName/smallpremium /mount/smallpremium -o vers=4,minorversion=1,sec=sys
sudo mkdir -p /mount/largepremium
sudo mount -t nfs $premiumFilesName.file.core.windows.net:/$premiumFilesName/largepremium /mount/largepremium -o vers=4,minorversion=1,sec=sys

## Mount Azure Files standard
sudo mkdir /mount/standard
sudo mount -t cifs //$standardStorageName.file.core.windows.net/standard  /mount/standard -o username=$standardStorageName,password=$standardStoragekey,serverino 

## Mount Blob standard
sudo mkdir /mount/blobstandard
sudo mount -o sec=sys,vers=3,nolock,proto=tcp $standardStorageName.blob.core.windows.net:/$standardStorageName/blobstandard  /mount/blobstandard

## Mount Blob premium
sudo mkdir /mount/blobpremium
sudo mount -o sec=sys,vers=3,nolock,proto=tcp $premiumBlobStorageName.blob.core.windows.net:/$premiumBlobStorageName/blobpremium  /mount/blobpremium

## Mount Azure NetApp Files
sudo mkdir -p /mount/netappstandard
sudo mount -t nfs -o rw,hard,rsize=1048576,wsize=1048576,sec=sys,vers=4.1,tcp 10.0.1.4:/netappstandard /mount/netappstandard
sudo mkdir -p /mount/netapppremium
sudo mount -t nfs -o rw,hard,rsize=1048576,wsize=1048576,sec=sys,vers=4.1,tcp 10.0.1.5:/netapppremium /mount/netapppremium
sudo mkdir -p /mount/netappultra
sudo mount -t nfs -o rw,hard,rsize=1048576,wsize=1048576,sec=sys,vers=4.1,tcp 10.0.1.4:/netappultra /mount/netappultra

## Metadata test
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/smallpremium     # 164 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/largepremium     # 170 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/standard         # 238 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/blobstandard     # 49 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/blobpremium      # 82 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/netappstandard   # 2933 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/netapppremium    # 3009 files per second
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 1024 --threads 4 --file-size 1 --top /mount/netappultra      # 2946 files per second
sudo rm -r /mount/


# Large file write
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/smallpremium      # 290 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/largepremium      # 342 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/standard          # 200 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/blobstandard      # 180 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/blobpremium       # 380 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/netappstandard    # 66 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/netapppremium     # 268 MiB/s
sudo python3 ./smallfile-1.0.1/smallfile_cli.py --operation create --files 4 --threads 4 --file-size 1000000 --top /mount/netappultra       # 512 MiB/s
sudo rm -r /mount/

# Latency test - read
sudo fio --runtime 30 smallpremium-sync-r.ini     # 3,3 ms
sudo fio --runtime 30 largepremium-sync-r.ini     # 3,3 ms
sudo fio --runtime 30 standard-sync-r.ini         # 22 ms
sudo fio --runtime 30 blobstandard-sync-r.ini     # 37 ms
sudo fio --runtime 30 blobpremium-sync-r.ini      # 6,5 ms
sudo fio --runtime 30 netappstandard-sync-r.ini   # 0,4 ms
sudo fio --runtime 30 netapppremium-sync-r.ini    # 0,4 ms
sudo fio --runtime 30 netappultra-sync-r.ini      # 0,4 ms
sudo rm -r /mount/

# Latency test - write
sudo fio --runtime 30 smallpremium-sync-w.ini     # 3,2 ms
sudo fio --runtime 30 largepremium-sync-w.ini     # 3,2 ms
sudo fio --runtime 30 standard-sync-w.ini         # 3,3 ms
sudo fio --runtime 30 blobstandard-sync-w.ini     # 112 ms - note fio is using update operation on single file, antipattern for blob
sudo fio --runtime 30 blobpremium-sync-w.ini      # 78 ms - note fio is using update operation on single file, antipattern for blob
sudo fio --runtime 30 netappstandard-sync-w.ini   # 0,4 ms
sudo fio --runtime 30 netapppremium-sync-w.ini    # 0,4 ms
sudo fio --runtime 30 netappultra-sync-w.ini      # 0,4 ms
sudo rm -r /mount/

# IOPS test - read
sudo fio --runtime 30 smallpremium-async-r.ini    # 4000 IOPS -> rated 500 with burst up to 4000
sudo fio --runtime 30 largepremium-async-r.ini    # 11500 IOPS -> rated 4400 with burst to 12000
sudo fio --runtime 30 standard-async-r.ini        # 1000 IOPS
sudo fio --runtime 30 blobstandard-async-r.ini    # 6600 IOPS
sudo fio --runtime 30 blobpremium-async-r.ini     # 6600 IOPS
sudo fio --runtime 30 netappstandard-async-r.ini  # 8200 IOPS
sudo fio --runtime 30 netapppremium-async-r.ini   # 32500 IOPS
sudo fio --runtime 30 netappultra-async-r.ini     # 30500 IOPS
sudo rm -r /mount/

# IOPS test - write
sudo fio --runtime 30 smallpremium-async-w.ini    # 4004 IOPS -> rated 500 with burst to 4000
sudo fio --runtime 30 largepremium-async-w.ini    # 12500 IOPS -> rated 4400 with burst to 12000
sudo fio --runtime 30 standard-async-w.ini        # 810 IOPS
sudo fio --runtime 30 blobstandard-async-w.ini    # 600 IOPS
sudo fio --runtime 30 blobpremium-async-w.ini     # 1400 IOPS
sudo fio --runtime 30 netappstandard-async-w.ini  # 8200 IOPS
sudo fio --runtime 30 netapppremium-async-w.ini   # 32800 IOPS
sudo fio --runtime 30 netappultra-async-w.ini     # 42800 IOPS
sudo rm -r /mount/


