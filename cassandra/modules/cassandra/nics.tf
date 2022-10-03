resource "azurerm_network_interface" "node1" {
  name                          = "${var.name_prefix}-node1-nic"
  location                      = var.rg_location
  resource_group_name           = var.rg_name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnetId
    private_ip_address_allocation = "Static"
    private_ip_address            = var.node1_ip
  }
}

resource "azurerm_network_interface" "node2" {
  name                = "${var.name_prefix}-node2-nic"
  location            = var.rg_location
  resource_group_name = var.rg_name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnetId
    private_ip_address_allocation = "Static"
    private_ip_address            = var.node2_ip
  }
}

resource "azurerm_network_interface" "node3" {
  name                = "${var.name_prefix}-node3-nic"
  location            = var.rg_location
  resource_group_name = var.rg_name
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnetId
    private_ip_address_allocation = "Static"
    private_ip_address            = var.node3_ip
  }
}
