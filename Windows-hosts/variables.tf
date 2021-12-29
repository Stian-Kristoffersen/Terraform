# Variables

variable "location" {
    description = "Azure Region"
    default = "North Europe"
}

variable "resource_group_name" {
    description = "Name of the Resource Group"
    default = "Windows-ResourceGroup"
}

variable "vm_name" {
    description = "Name of the VM"
    type        = list(string)
    default     = ["Client1"]
}

variable "ip_whitelist" {
    description = "A list of CIDRs that will be allowed to access the instances"
    type        = list(string)
    default     = ["79.160.193.112/32"]
}

variable "admin_username" {
    description = "Admin username"
    default = "terraform"
}

variable "admin_password" {
    description = "Admin password"
    default = "P@ssw0rd123456!"

}