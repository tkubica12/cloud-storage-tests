# resource "azurerm_managed_disk" "node1_premiumv2" {
#   count                = var.disk_type == "premiumv2" ? 1 : 0
#   name                 = "${var.name_prefix}-node1-disk"
#   location             = var.rg_location
#   resource_group_name  = var.rg_name
#   storage_account_type = "PremiumV2_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = "1024"
#   zone                 = 1
#   disk_iops_read_write = var.disk_iops
#   disk_mbps_read_write = var.disk_mbps
# }

resource "azapi_resource" "node1_premiumv2" {
  count     = var.disk_type == "premiumv2" ? 1 : 0
  type      = "Microsoft.Compute/disks@2022-03-02"
  name      = "${var.name_prefix}-node1-disk"
  location  = var.rg_location
  parent_id = var.rg_id
  body = jsonencode({
    properties = {
      creationData = {
        createOption      = "Empty"
        logicalSectorSize = 4096
      }
      diskIOPSReadWrite = var.disk_iops
      diskMBpsReadWrite = var.disk_mbps
      diskSizeGB        = var.disk_size
    }
    zones = [
      "1"
    ]
    sku = {
      name = "PremiumV2_LRS"
    }
  })
}

resource "azapi_resource" "node2_premiumv2" {
  count     = var.disk_type == "premiumv2" ? 1 : 0
  type      = "Microsoft.Compute/disks@2022-03-02"
  name      = "${var.name_prefix}-node2-disk"
  location  = var.rg_location
  parent_id = var.rg_id
  body = jsonencode({
    properties = {
      creationData = {
        createOption      = "Empty"
        logicalSectorSize = 4096
      }
      diskIOPSReadWrite = var.disk_iops
      diskMBpsReadWrite = var.disk_mbps
      diskSizeGB        = var.disk_size
    }
    zones = [
      "2"
    ]
    sku = {
      name = "PremiumV2_LRS"
    }
  })
}

resource "azapi_resource" "node3_premiumv2" {
  count     = var.disk_type == "premiumv2" ? 1 : 0
  type      = "Microsoft.Compute/disks@2022-03-02"
  name      = "${var.name_prefix}-node3-disk"
  location  = var.rg_location
  parent_id = var.rg_id
  body = jsonencode({
    properties = {
      creationData = {
        createOption      = "Empty"
        logicalSectorSize = 4096
      }
      diskIOPSReadWrite = var.disk_iops
      diskMBpsReadWrite = var.disk_mbps
      diskSizeGB        = var.disk_size
    }
    zones = [
      "3"
    ]
    sku = {
      name = "PremiumV2_LRS"
    }
  })
}

resource "azurerm_virtual_machine_data_disk_attachment" "node1_premiumv2" {
  count              = var.disk_type == "premiumv2" ? 1 : 0
  managed_disk_id    = azapi_resource.node1_premiumv2[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.node1.id
  lun                = "0"
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "node2_premiumv2" {
  count              = var.disk_type == "premiumv2" ? 1 : 0
  managed_disk_id    = azapi_resource.node2_premiumv2[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.node2.id
  lun                = "0"
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "node3_premiumv2" {
  count              = var.disk_type == "premiumv2" ? 1 : 0
  managed_disk_id    = azapi_resource.node3_premiumv2[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.node3.id
  lun                = "0"
  caching            = "None"
}
