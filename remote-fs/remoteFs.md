# Azure remote file system performance test
This repo contains few test scenarios on remote files systems in Azure including:
- Azure Files Standard (via CIFS)
- Azure Files Premium (via NFS)
- Azure Blob Standard (via NFS)
- Azure Blob Premium (via NFS)
- Azure NetApp Files Standard (via NFS)
- Azure NetApp Files Premium (via NFS)
- Azure NetApp Files Ultra (via NFS)

First prepare Azure infrastructure:
[prepare.sh](prepare.sh)

Next run tests in VM:
[test.sh](test.sh)

Summary results:
[./results.xlsx](./results.xlsx)

Findings:
- Metadata and latency is by far best with Azure NetApp Files (great for lots of small files)
- Price per throughput and read IOPS is by far best with Azure Blob Standard (great for data lake, movie files etc.)
- High-end IOPS are best and most cost effective with Azure NetApp Files
- Azure Files comes with very strong price/performance when smaller shares are needed (NetApp Files has 4TB minimum, Azure Files scale from zero)

My person recommendations:
- For data lake, archival or media use Azure Blob
- For operational files (including storage for DB files etc.) use Azure NetApp Files and make sure you share pool with other projects to overcome 4TB "entry to the club fee"
- For small shares use Azure Files
- Azure Files Cool tier can be great for archival when your solution needs standard file system behavior (otherwise prefer Blobs)