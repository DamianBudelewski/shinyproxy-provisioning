# Jumpbox configuration
resource "azurerm_public_ip" "jumpbox" {
    name				= "jumpbox-public-ip"
    location				= azurerm_resource_group.resourcegroup.location
    resource_group_name			= azurerm_resource_group.resourcegroup.name
    allocation_method			= "Static"
    domain_name_label			= "${random_string.fqdn.result}-ssh"
}

resource "azurerm_network_interface" "jumpbox" {
    name				= "jumpbox-nic"
    location				= azurerm_resource_group.resourcegroup.location
    resource_group_name			= azurerm_resource_group.resourcegroup.name
    
    ip_configuration {
    	name				= "IPConfiguration"
    	subnet_id			= azurerm_subnet.backend.id
    	private_ip_address_allocation	= "dynamic"
    	public_ip_address_id		= azurerm_public_ip.jumpbox.id
    }
}

resource "azurerm_virtual_machine" "jumpbox" {
    name				= "jumpbox"
    location				= azurerm_resource_group.resourcegroup.location
    resource_group_name			= azurerm_resource_group.resourcegroup.name
    network_interface_ids		= [azurerm_network_interface.jumpbox.id]
    vm_size 				= "Standard_B1ms"

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }
    
    storage_os_disk {
        name              = "jumpbox-osdisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name  = "jumpbox"
    	admin_username = "dbudelewski"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            key_data	= file("~/.ssh/id_rsa.pub")
            path	= "/home/dbudelewski/.ssh/authorized_keys"
        }
    }
}
