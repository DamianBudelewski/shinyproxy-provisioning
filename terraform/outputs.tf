data "azurerm_public_ip" "shinyapppublicip" {
    name		= azurerm_public_ip.shinyapppublicip.name
    resource_group_name	= azurerm_virtual_machine.shinyappvm.resource_group_name
}

output "public_ip_address" {
    value		= data.azurerm_public_ip.shinyapppublicip.ip_address
}
