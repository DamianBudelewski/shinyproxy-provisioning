data "azurerm_public_ip" "publicip" {
    name		= azurerm_public_ip.publicip.name
    resource_group_name	= azurerm_resource_group.resourcegroup.name
}

data "azurerm_public_ip" "jumpbox" {
    name		= azurerm_public_ip.jumpbox.name
    resource_group_name	= azurerm_resource_group.resourcegroup.name
}

output "public_ip_address" {
    value		= data.azurerm_public_ip.publicip.ip_address
}

output "fqdn" {
    value		= data.azurerm_public_ip.publicip.fqdn
}

output "public_ip_address-jumpbox" {
    value		= data.azurerm_public_ip.jumpbox.ip_address
}

output "fqdn-jumpbox" {
    value		= data.azurerm_public_ip.jumpbox.fqdn
}

