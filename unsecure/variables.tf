variable "resource_group_name" {
  description = "Grupa zasobów"
  type        = string
  default     = "rg-project-unsecure"
}

variable "location_a" {
  description = "Region dla VM-A"
  type        = string
  default     = "polandcentral"
}

variable "location_b" {
  description = "Region dla VM-B"
  type        = string
  default     = "japaneast"
}

variable "admin_username" {
  description = "Nazwa użytkownika admina na VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Hasło admina na VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Rozmiar VM"
  type        = string
  default     = "Standard_B1s"
}
