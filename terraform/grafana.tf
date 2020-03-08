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
        image  = "grafana/grafana:6.5.0"
        cpu    = "0.5"
        memory = "1.5"
        
        ports {
            port     = "3000"
            protocol = "TCP"
        }

	volume {
	    name = "config"
	    mount_path = "/etc/grafana"
	    read_only = "true"
	    storage_account_name = azurerm_storage_account.storageaccount.name
	    storage_account_key = azurerm_storage_account.storageaccount.primary_access_key
	    share_name = "grafana-config"
	}
    }
}
