output "publicip" {
  value = azurerm_public_ip.publicip["Client1"].ip_address
}