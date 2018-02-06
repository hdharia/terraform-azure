output "ssh ip_address" {
  value = "ssh ${var.admin_username}@${data.azurerm_public_ip.test.ip_address}"
}