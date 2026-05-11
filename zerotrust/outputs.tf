output "vm_a_private_ip" {
  description = "Prywatny IP VM-A"
  value       = azurerm_network_interface.vm_a.private_ip_address
}

output "vm_b_private_ip" {
  description = "Prywatny IP VM-B"
  value       = azurerm_network_interface.vm_b.private_ip_address
}
