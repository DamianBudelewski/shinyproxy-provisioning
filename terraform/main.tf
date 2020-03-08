provider "azurerm" {
  version = "= 1.33.0"
}

terraform {
    backend "azurerm" {
        resource_group_name	= "tfstate-rg"
        storage_account_name	= "stacctfstate9n63x"
        container_name		= "btc"
        key			= "terraform.tfstate"
    }
}

# Generate random string for jumpbox fqdn
resource "random_string" "fqdn" {
    length  = 6
    special = false
    upper   = false
    number  = false
}

# Create a resource group if it doesnt exist
resource "azurerm_resource_group" "resourcegroup" {
    name     = var.bitcoingtrends["rg_name"]
    location = var.bitcoingtrends["location"]
}

# Create virtual network
resource "azurerm_virtual_network" "network" {
    name                = "vnet"
    address_space       = ["10.254.0.0/16"]
    resource_group_name = azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
}

# Create frontend subnet.
resource "azurerm_subnet" "frontend" {
    name                 = "frontend"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.254.0.0/24"
}

# Create backend subnet.
resource "azurerm_subnet" "backend" {
    name                 = "backend"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.254.2.0/24"
}

# Create backend container instance subnet.
resource "azurerm_subnet" "backend-aci" {
    name                 = "backend-aci"
    resource_group_name  = azurerm_resource_group.resourcegroup.name
    virtual_network_name = azurerm_virtual_network.network.name
    address_prefix       = "10.254.3.0/24"

    delegation {
        name = "delegation"
        
        service_delegation {
            name    = "Microsoft.ContainerInstance/containerGroups"
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "networksecurity" {
    name		= "nsg"
    resource_group_name	= azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 999
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create network interfaces
resource "azurerm_network_interface" "nic" {
    count			= 2
    name			= "nic${count.index}"
    resource_group_name		= azurerm_resource_group.resourcegroup.name
    location			= azurerm_resource_group.resourcegroup.location
    network_security_group_id	= azurerm_network_security_group.networksecurity.id

    ip_configuration {
        name				= "nic-config"
        subnet_id			= azurerm_subnet.backend.id
	private_ip_address		= "10.254.2.${count.index + 6}"
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
resource "azurerm_virtual_machine" "vm" {
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
        computer_name  = "btcgtrends${count.index}"
    	admin_username = "dbudelewski"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            key_data	= file("~/.ssh/id_rsa.pub")
            path	= "/home/dbudelewski/.ssh/authorized_keys"
        }
    }

    boot_diagnostics {
        enabled		= "true"
        storage_uri	= azurerm_storage_account.storageaccount.primary_blob_endpoint
    }
}
