output "vm_a_public_ip" {
  description = "Publiczny IP VM-A"
  value       = azurerm_public_ip.vm_a.ip_address
}

output "vm_b_public_ip" {
  description = "Publiczny IP VM-B"
  value       = azurerm_public_ip.vm_b.ip_address
}

output "vm_a_private_ip" {
  description = "Prywatny IP VM-A"
  value       = azurerm_network_interface.vm_a.private_ip_address
}

output "vm_b_private_ip" {
  description = "Prywatny IP VM-B"
  value       = azurerm_network_interface.vm_b.private_ip_address
}

output "ssh_command_vm_a" {
  description = "Polecenie SSH do VM-A"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm_a.ip_address}"
}

output "ssh_command_vm_b" {
  description = "Polecenie SSH do VM-B"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm_b.ip_address}"
}
