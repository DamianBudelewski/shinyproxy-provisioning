provider "azurerm" {
  version = "= 1.33.0"
}

# Locals block for hardcoded names. 
locals {
    backend_address_pool_name      = "${azurerm_virtual_network.network.name}-beap"
    frontend_ip_configuration_name = "${azurerm_virtual_network.network.name}-feip"
    frontend_port_name             = "${azurerm_virtual_network.network.name}-feport"
    http_setting_name              = "${azurerm_virtual_network.network.name}-be-htst"
    listener_name                  = "${azurerm_virtual_network.network.name}-httplstn"
    request_routing_rule_name      = "${azurerm_virtual_network.network.name}-rqrt"
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

# Create public IP for application gateway
resource "azurerm_public_ip" "publicip" {
    name		= "publicip"
    allocation_method	= "Static"
    domain_name_label	= var.bitcoingtrends["fqdn"]
    resource_group_name	= azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location
    sku			= "Standard"
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


resource "azurerm_application_gateway" "gateway" {
    name                = "app-gw"
    resource_group_name = azurerm_resource_group.resourcegroup.name
    location		= azurerm_resource_group.resourcegroup.location

    sku {
        name     = "Standard_v2"
        tier     = "Standard_v2"
        capacity = 2
    }

    gateway_ip_configuration {
        name      = "app-gw-cfg"
        subnet_id = azurerm_subnet.frontend.id
    }

    frontend_port {
        name = local.frontend_port_name
        port = 80
    }
    
    frontend_port {
        name = "httpsPort"
        port = 443
    }
    
    frontend_ip_configuration {
        name                 = local.frontend_ip_configuration_name
        public_ip_address_id = azurerm_public_ip.publicip.id
    }
    
    backend_address_pool {
        name = local.backend_address_pool_name
    }
    
    backend_http_settings {
        name                  = local.http_setting_name
        cookie_based_affinity = "Disabled"
        port                  = 80
        protocol              = "Http"
        request_timeout       = 1
    }
    
    http_listener {
        name                           = local.listener_name
        frontend_ip_configuration_name = local.frontend_ip_configuration_name
        frontend_port_name             = local.frontend_port_name
        protocol                       = "Http"
    }
    
    request_routing_rule {
        name                       = local.request_routing_rule_name
        rule_type                  = "Basic"
        http_listener_name         = local.listener_name
        backend_address_pool_name  = local.backend_address_pool_name
        backend_http_settings_name = local.http_setting_name
    }
    
    depends_on = ["azurerm_virtual_network.network", "azurerm_public_ip.publicip"]
}

# Storage share for grafana instance volume
resource "azurerm_storage_share" "grafana" {
    name                 = "grafana"
    storage_account_name = azurerm_storage_account.storageaccount.name
    quota                = 50
}

# Create network profile to attach grafana instance into vnet
resource "azurerm_network_profile" "grafana" {
    name                = "grafana-net-profile"
    location            = azurerm_resource_group.resourcegroup.location
    resource_group_name = azurerm_resource_group.resourcegroup.name
    
    container_network_interface {
        name = "grafana-nic"
        
        ip_configuration {
            name      = "grafana-nic-cfg"
            subnet_id = azurerm_subnet.backend-aci.id
        }
    }
}

# Create grafana container instance
resource "azurerm_container_group" "grafana" {
    name                = "grafana-aci"
    location            = azurerm_resource_group.resourcegroup.location
    resource_group_name = azurerm_resource_group.resourcegroup.name
    ip_address_type     = "private"
    network_profile_id  = azurerm_network_profile.grafana.id
    os_type             = "Linux"
    
    container {
        name   = "grafana"
        image  = "microsoft/aci-helloworld:latest"
        cpu    = "0.5"
        memory = "1.5"
        
        volume {
            name = "grafana-volume"
            storage_account_name = azurerm_storage_account.storageaccount.name
            storage_account_key = azurerm_storage_account.storageaccount.primary_access_key
            share_name = azurerm_storage_share.grafana.name
            mount_path = "/var/lib/grafana/"
        }
        
        ports {
            port     = 80
            protocol = "TCP"
        }
    }
}

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
