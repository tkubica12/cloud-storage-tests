# AKS storage

## Singleton
- Single-instance for legacy app or cheap "HA"
  - Nodepool upgrade = some downtime
  - Node crash = potential app-level data corruption (eg. DB recovery needed after restart)
- Moderate performance needs
  - Prefer ZRS NAS (Azure Files) if file based solution is enough (eg. no need for hard links)
  - For block use iSCSI based Azure Elastic SAN (in preview)
  - For higher performance or lower cost use ZRS-based Azure Disk
    (slower failover times, use CSI v2 with multi-attach to achieve about 15s reconnection)
    (beware of mount limits per node)
- High performance
  - Due to physics you gonna need in-AZ storage therefore no AZ redundancy
  - Prefer Azure NetApp Files (Premium or Ultra tier)
  - Use Premium SSD v2 LRS or UltraSSD
  - To survive AZ failure you need DR eg. backups to different AZ

## Shared storage
- Multi-instance solution, typically legacy DB cluster or web farm
- Moderate performance needs
  - Prefer ZRS NAS (Azure Files) if file based solution is enough (eg. no need for hard links)
  - Try to avoid block devices due to complexity
    - you must use volumeMode:block
    - you need clustered file system to deal with SCSI PR (no ext4 or xfs !)
    - possible if doe right, but complex - use Standard SSD or Premium SSD v2 for zone redundancy (ZRS)
- High performance
  - Prefer Azure NetApp Files (Premium or Ultra tier)
  - Try to avoid block devices due to complexity
    - you must use volumeMode:block
    - you need clustered file system to deal with SCSI PR (no ext4 or xfs !)
    - possible if done right, but complex - use Ultra SSD or Premium SSD v2 for high performance (LRS)


## Shared nothing
- Each instance comes with its own storage and data is replicated on app/db level (eg. Elastic, Cassandra, Kafka, ...)
- Moderate performance
  - Prefer Azure Disks in LRS -> Standard SSD or Premium SSD v2
    (beware of mount limits per node)
  - If mount limits is problem, consider Elastic SAN (iSCSI - in preview) or NAS
- High performance
  - Prefer Azure Disks in LRS -> Premium SSD v2 or Ultra SSD
    (beware of mount limits per node)
- Extreme storage performance
  - Prefer Ultra SSD Azure Disk
  - You may consider local storage such as NVMe on L-series VMs
    - Note every nodepool upgrade = series of failovers, make sure you know how to handle that (for experts only)
    - Avoid using hostPath or simple manualy provisioned Local Persistent Volumes
    - Look for automated solution such as NativStore
    - Consider adding another storage layer such as Portworx (by Pure Storage)