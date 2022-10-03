locals {
  location = "westeurope"
}

// Resource Group
resource "azurerm_resource_group" "main" {
  name     = "cassandra"
  location = local.location
}

// Network
resource "azurerm_virtual_network" "main" {
  name                = "cassandra-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "client" {
  name                 = "client"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "cluster" {
  name                 = "cluster"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

// Clusters
module "cluster" {
  source      = "./modules/cassandra"
  name_prefix = "cluster"
  disk_type   = var.disk_type
  subnetId    = azurerm_subnet.cluster.id
  node1_ip    = "10.0.1.11"
  node2_ip    = "10.0.1.12"
  node3_ip    = "10.0.1.13"
  rg_location = azurerm_resource_group.main.location
  rg_name     = azurerm_resource_group.main.name
  rg_id       = azurerm_resource_group.main.id
  disk_iops   = var.disk_iops
  disk_mbps   = var.disk_mbps
  disk_size   = var.disk_size
}

// Client node
resource "azurerm_network_interface" "client" {
  name                          = "client-nic"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.client.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "client" {
  name                            = "client"
  computer_name                   = "client"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_D16ds_v4"
  admin_username                  = "adminuser"
  admin_password                  = "Azure12345678"
  disable_password_authentication = false
  zone                            = 1

  boot_diagnostics {}

  network_interface_ids = [
    azurerm_network_interface.client.id,
  ]

  os_disk {
    caching = "ReadOnly"
    storage_account_type = "Standard_LRS"

    diff_disk_settings {
      placement = "CacheDisk"
      option    = "Local"
    }
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
