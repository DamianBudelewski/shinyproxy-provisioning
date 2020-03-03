provider "azurerm" {
  version = "= 1.33.0"
}

# Create a resource group if it doesnt exist
resource "azurerm_resource_group" "resourcegroup" {
    name     = var.bitcoingtrends["rg_name"]
    location = var.bitcoingtrends["location"]
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
    name                = "virtual-network"
    address_space       = ["10.254.0.0/16"]
    resource_group_name = azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
}

# Create frontend subnet.
resource "azurerm_subnet" "subnet_frontend" {
    name                 = "subnet"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.254.0.0/24"
}

# Create backend subnet.
resource "azurerm_subnet" "subnet_backend" {
    name                 = "subnet"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.254.2.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "publicip" {
    name		= "publicip"
    allocation_method	= "Dynamic"
    domain_name_label	= var.bitcoingtrends["fqdn"]
    resource_group_name	= azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
}

# Create network interfaces
resource "azurerm_network_interface" "nic" {
    count			= 2
    name			= "nic${count.index}"
    resource_group_name		= azurerm_resource_group.resourcegroup.name
    location			= azurerm_resource_group.resourcegroup.location
    network_security_group_id	= azurerm_network_security_group.networksecurity.id

    ip_configuration {
        name				= "nic-2-config"
        subnet_id			= azurerm_subnet.subnet_backend.id
	private_ip_address		= "10.254.2.${count.index}"
        private_ip_address_allocation	= "Static"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.resourcegroup.name
    }
    
    byte_length = 8
}

resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name		= azurerm_resource_group.resourcegroup.name
    location			= azurerm_resource_group.resourcegroup.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Create virtual machines
resource "azurerm_virtual_machine" "test" {
    count				= 2
    name 				= "vm${count.index}"
    resource_group_name			= azurerm_resource_group.resourcegroup.name
    location 				= azurerm_resource_group.resourcegroup.location
    network_interface_ids		= [element(azurerm_network_interface.nic.*.id, count.index)]
    delete_os_disk_on_termination 	= true
    delete_data_disks_on_termination 	= true
    vm_size 				= "Standard_B1ms"

    storage_image_reference {
        publisher = "OpenLogic"
        offer     = "CentOS"
        sku       = "7.7"
        version   = "latest"
    }

    storage_os_disk {
        name              = "osdisk${count.index}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    os_profile {
        computer_name  = "btcgtrends"
    	admin_username = "dbudelewski"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            key_data	= file("~/.ssh/id_rsa.pub")
            path	= "~/.ssh/authorized_keys"
        }
    }

    boot_diagnostics {
        enabled		= "true"
        storage_uri	= azurerm_storage_account.storageaccount.primary_blob_endpoint
    }
}
