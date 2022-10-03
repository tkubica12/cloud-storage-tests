resource "azurerm_managed_disk" "node1_ultra" {
  count                = var.disk_type == "ultra" ? 1 : 0
  name                 = "${var.name_prefix}-node1-disk"
  location             = var.rg_location
  resource_group_name  = var.rg_name
  storage_account_type = "UltraSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = tostring(var.disk_size)
  zone                 = 1
  disk_iops_read_write = var.disk_iops
  disk_mbps_read_write = var.disk_mbps
}

resource "azurerm_managed_disk" "node2_ultra" {
  count                = var.disk_type == "ultra" ? 1 : 0
  name                 = "${var.name_prefix}-node2-disk"
  location             = var.rg_location
  resource_group_name  = var.rg_name
  storage_account_type = "UltraSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = tostring(var.disk_size)
  zone                 = 2
  disk_iops_read_write = var.disk_iops
  disk_mbps_read_write = var.disk_mbps
}

resource "azurerm_managed_disk" "node3_ultra" {
  count                = var.disk_type == "ultra" ? 1 : 0
  name                 = "${var.name_prefix}-node3-disk"
  location             = var.rg_location
  resource_group_name  = var.rg_name
  storage_account_type = "UltraSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = tostring(var.disk_size)
  zone                 = 3
  disk_iops_read_write = var.disk_iops
  disk_mbps_read_write = var.disk_mbps
}

resource "azurerm_virtual_machine_data_disk_attachment" "node1_ultra" {
  count              = var.disk_type == "ultra" ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.node1_ultra[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.node1.id
  lun                = "0"
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "node2_ultra" {
  count              = var.disk_type == "ultra" ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.node2_ultra[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.node2.id
  lun                = "0"
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "node3_ultra" {
  count              = var.disk_type == "ultra" ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.node3_ultra[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.node3.id
  lun                = "0"
  caching            = "None"
}
