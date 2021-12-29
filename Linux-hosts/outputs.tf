output "publicip" {
  value = azurerm_public_ip.publicip["Linux-node1"].ip_address
}