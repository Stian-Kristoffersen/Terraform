# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.8"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg" {
    name     = var.resource_group_name
    location = var.location
}

# Create a random id for Storage Account (must be uniqe)
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group_name  = azurerm_resource_group.rg.name
  }
  byte_length = 8
}

# Create Storage Account
resource "azurerm_storage_account" "storage" {
  name                      = "diag${random_id.randomId.hex}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  account_replication_type  = "LRS"
  account_tier              = "Standard"
}

# Create Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                  = "Windows-nsg"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name

  # RDP
  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "network" {
  name                = "virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnet for internal interfaces
resource "azurerm_subnet" "subnet" {
  name                 = "internal-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Make association to Network Security Group and rules
resource "azurerm_subnet_network_security_group_association" "nsga" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create Public IP interface
resource "azurerm_public_ip" "publicip" {
  for_each           = toset(var.vm_name)
  #name                = each.value
  name                = "${each.value}-publicip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create Internal network interface (NIC)
resource "azurerm_network_interface" "nic" {
  for_each            = toset(var.vm_name)
  #name               = each.value
  name                = "${each.value}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "windows-node_NicConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip[each.key].id
  }
}

# Create Windows Virtual Machine 
resource "azurerm_windows_virtual_machine" "vm" {
  for_each              = toset(var.vm_name)
  name                  = "${each.value}-vm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_F2"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  provision_vm_agent    = "true"
  custom_data           = filebase64("./files/bootstrap.ps1")
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Additional setup Part 1
  additional_unattend_content {
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
    setting = "AutoLogon"
  }

  # Additional setup Part 2
  additional_unattend_content {
    content = file("./files/FirstLogonCommands.xml")
    setting = "FirstLogonCommands"
  }

  # Create Windows Image
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-21h2-pron"
    version   = "latest"
  } 
}