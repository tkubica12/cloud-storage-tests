# Simple Cassandra perf test
Terraform template is provided to create client and 3-node Cassandra cluster across availability zones using either Premium SSD, Premium SSD v2 or Ultra SSD disks. Various tfvars files are provided for different infrastructure configurations.

1. Deploy infrastructure with Premium SSD
```
terraform init
terraform apply -auto-approve -var-file=premiumv1.tfvars
```

2. Connect to client VM using serial connection via portal, install Docker and run perf-test. 
```
# Install Docker
sudo snap install docker

# Write test with 3-way replication
sudo docker run --rm chrisbelyea/cassandra-stress:latest "write duration=10s cl=LOCAL_QUORUM -node 10.0.1.11,10.0.1.12,10.0.1.13 -schema replication(factor=3) -rate threads=800"
```

3. Delete infrastructure
```
terraform destroy -auto-approve -var-file=premiumv1.tfvars
```

4. Repeat for other scenarios using different tfvars files
- premiumv1.tfvars -> 1TB Premium SSD
- premiumv2-same.tfvars -> 1TB Premium SSD v2 with 5000 IOPS and 200 Mbps
- ultra-same.tfvars -> 1TB Ultra SSD with 5000 IOPS and 200 Mbps
- premiumv2-fast.tfvars -> 1TB Premium SSD v2 with 25000 IOPS and 600 Mbps
- ultra-fast.tfvars -> 1TB Ultra SSD with 25000 IOPS and 600 Mbps


Note: We do not need to destroy infrastructure between different performance configurations of the same disk type. Eg. when applying premiumv2-same.tfvars you can then just apply premiumv2-fast.tfvars as this change is done live. However, if you want to change disk type, you need to destroy infrastructure first.