data "azurerm_public_ip" "publicip" {
    name		= azurerm_public_ip.publicip.name
    resource_group_name	= azurerm_virtual_machine.vm.resource_group_name
}

output "public_ip_address" {
    value		= data.azurerm_public_ip.publicip.ip_address
}

output "fqdn" {
    value		= data.azurerm_public_ip.publicip.fqdn
}
