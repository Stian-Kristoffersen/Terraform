# Variables

variable "location" {
    description = "Azure Region"
    default = "North Europe"
}

variable "resource_group_name" {
    description = "Name of the Resource Group"
    default = "Linux-ResourceGroup"
}

variable "vm_name" {
    description = "Name of the VM"
    type        = list(string)
    default     = ["Linux-node1"]
}

variable "ip_whitelist" {
    description = "A list of CIDRs that will be allowed to access the instances"
    type        = list(string)
    default     = ["79.160.193.112/32"]
}

