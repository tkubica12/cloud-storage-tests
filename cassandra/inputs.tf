variable "disk_type" {
  type = string
  validation {
    condition = contains(["premiumv1", "premiumv2", "ultra"], var.disk_type)
    error_message = "Disk type must be one of: premiumv1, premiumv2, ultra."
  }
}

variable "disk_iops" {
  type = number
  default = 0
}

variable "disk_mbps" {
  type = number
  default = 0
}

variable "disk_size" {
  type = number
  default = 1024
}

variable "vm_sku" {
  type = string
  default = "Standard_D16s_v5"
}

variable "vm_password" {
  type = string
  default = "Azure12345678"
}

variable "vm_user" {
  type = string
  default = "adminuser"
}