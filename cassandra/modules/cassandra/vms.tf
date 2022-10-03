locals {
  script_node1 = <<SCRIPT
#!/bin/bash
# Install Docker
snap install docker

# Wait for disk
until [ -e /dev/sdb ]; do
    echo "Waiting for disk"
    sleep 10
done

# Create partition on disk
fdisk /dev/sdb <<EOF
n
p
1
1


w
EOF

# Create file system
mkfs.ext4 /dev/sdb1

# Mount disk
mkdir -p /mnt/disk
mount /dev/sdb1 /mnt/disk

# Run Cassandra
docker run --name cassandra \
  -v /mnt/disk:/var/lib/cassandra \
  -d \
  -p 7000:7000 -p 9042:9042 \
  -e CASSANDRA_BROADCAST_ADDRESS=${var.node1_ip} \
  -e CASSANDRA_SEEDS=${var.node1_ip},${var.node2_ip},${var.node3_ip} \
  -e CASSANDRA_CLUSTER_NAME=${var.name_prefix} \
  cassandra:4.0.6
SCRIPT

  script_node2 = <<SCRIPT
#!/bin/bash
# Install Docker
snap install docker

# Wait for disk
until [ -e /dev/sdb ]; do
    echo "Waiting for disk"
    sleep 10
done

# Create partition on disk
fdisk /dev/sdb <<EOF
n
p
1
1


w
EOF

# Create file system
mkfs.ext4 /dev/sdb1

# Mount disk
mkdir -p /mnt/disk
mount /dev/sdb1 /mnt/disk

# Run Cassandra
docker run --name cassandra \
  -v /mnt/disk:/var/lib/cassandra \
  -d \
  -p 7000:7000 -p 9042:9042 \
  -e CASSANDRA_BROADCAST_ADDRESS=${var.node2_ip} \
  -e CASSANDRA_SEEDS=${var.node1_ip},${var.node2_ip},${var.node3_ip} \
  -e CASSANDRA_CLUSTER_NAME=${var.name_prefix} \
  cassandra:4.0.6
SCRIPT

  script_node3 = <<SCRIPT
#!/bin/bash
# Install Docker
snap install docker

# Wait for disk
until [ -e /dev/sdb ]; do
    echo "Waiting for disk"
    sleep 10
done

# Create partition on disk
fdisk /dev/sdb <<EOF
n
p
1
1


w
EOF

# Create file system
mkfs.ext4 /dev/sdb1

# Mount disk
mkdir -p /mnt/disk
mount /dev/sdb1 /mnt/disk

# Run Cassandra
docker run --name cassandra \
  -v /mnt/disk:/var/lib/cassandra \
  -d \
  -p 7000:7000 -p 9042:9042 \
  -e CASSANDRA_BROADCAST_ADDRESS=${var.node3_ip} \
  -e CASSANDRA_SEEDS=${var.node1_ip},${var.node2_ip},${var.node3_ip} \
  -e CASSANDRA_CLUSTER_NAME=${var.name_prefix} \
  cassandra:4.0.6
SCRIPT
}

resource "azurerm_linux_virtual_machine" "node1" {
  name                            = "${var.name_prefix}-node1"
  computer_name                   = "cassandra1"
  location                        = var.rg_location
  resource_group_name             = var.rg_name
  size                            = var.vm_sku
  admin_username                  = var.vm_user
  admin_password                  = var.vm_password
  disable_password_authentication = false
  zone                            = 1
  custom_data                     = base64encode(local.script_node1)

  boot_diagnostics {}

  network_interface_ids = [
    azurerm_network_interface.node1.id,
  ]

  additional_capabilities {
    ultra_ssd_enabled = true
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "node2" {
  name                            = "${var.name_prefix}-node2"
  computer_name                   = "cassandra2"
  location                        = var.rg_location
  resource_group_name             = var.rg_name
  size                            = var.vm_sku
  admin_username                  = var.vm_user
  admin_password                  = var.vm_password
  disable_password_authentication = false
  zone                            = 2
  custom_data                     = base64encode(local.script_node2)

  boot_diagnostics {}

  network_interface_ids = [
    azurerm_network_interface.node2.id,
  ]

  additional_capabilities {
    ultra_ssd_enabled = true
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "node3" {
  name                            = "${var.name_prefix}-node3"
  computer_name                   = "cassandra3"
  location                        = var.rg_location
  resource_group_name             = var.rg_name
  size                            = var.vm_sku
  admin_username                  = var.vm_user
  admin_password                  = var.vm_password
  disable_password_authentication = false
  zone                            = 3
  custom_data                     = base64encode(local.script_node3)

  boot_diagnostics {}

  network_interface_ids = [
    azurerm_network_interface.node3.id,
  ]

  additional_capabilities {
    ultra_ssd_enabled = true
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
