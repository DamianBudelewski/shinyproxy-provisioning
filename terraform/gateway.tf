# Locals block for hardcoded names. 
locals {
    backend_address_pool_name      = "${azurerm_virtual_network.network.name}-beap"
    frontend_ip_configuration_name = "${azurerm_virtual_network.network.name}-feip"
    frontend_port_name             = "${azurerm_virtual_network.network.name}-feport"
    http_setting_name              = "${azurerm_virtual_network.network.name}-be-htst"
    listener_name                  = "${azurerm_virtual_network.network.name}-httplstn"
    request_routing_rule_name      = "${azurerm_virtual_network.network.name}-rqrt"
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

# Create application gateway resource
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
   
    request_routing_rule {
        name                       	= "http2https"
        rule_type                  	= "Basic"
        http_listener_name         	= "http"
	redirect_configuration_name	= "http2https"
    }

    request_routing_rule {
	name				= "redirect"
        http_listener_name         	= "https"
        rule_type			= "PathBasedRouting"
        url_path_map_name		= "redirect"
    }

    url_path_map {
        name					= "redirect"
        default_backend_address_pool_name	= "shiny"
        default_backend_http_settings_name	= "http-shiny"
        path_rule {
            backend_address_pool_name		= "grafana"
            backend_http_settings_name		= "http-grafana"
            name				= "grafana"
            paths				= ["/grafana"]
        }
    }

    ssl_certificate {
       name		= "cert.pfx"
       data		= filebase64("cert.pfx")
       password		= var.bitcoingtrends["password-pfx"]
    }

    ssl_policy {
       min_protocol_version = "TLSv1_2"
    }

    redirect_configuration {
        name = "http2https"
	redirect_type = "Permanent"
	target_listener_name = "https"
	include_path = "true"
	include_query_string = "true"
    }
    
    frontend_ip_configuration {
        name                 = local.frontend_ip_configuration_name
        public_ip_address_id = azurerm_public_ip.publicip.id
    }

    backend_address_pool {
        name = "shiny"
        ip_addresses = ["10.254.2.6", "10.254.2.7"]
    }
    
    backend_address_pool {
        name = "grafana"
        ip_addresses = ["${azurerm_container_group.grafana.ip_address}"]
    }

    http_listener {
        name                           = "http"
        frontend_ip_configuration_name = local.frontend_ip_configuration_name
        frontend_port_name             = local.frontend_port_name
        protocol                       = "Http"
    }

    http_listener {
        name                           = "https"
        frontend_ip_configuration_name = local.frontend_ip_configuration_name
        frontend_port_name             = "httpsPort"
        protocol                       = "Https"
        ssl_certificate_name		= "cert.pfx"
    }

    backend_http_settings {
        name                  = "http-shiny"
        cookie_based_affinity = "Enabled"
        port                  = "8080"
        protocol              = "Http"
        request_timeout       = 60
    }

    backend_http_settings {
        name                  = "http-grafana"
        cookie_based_affinity = "Enabled"
        port                  = "3000"
        protocol              = "Http"
        request_timeout       = 60
    }

    rewrite_rule_set {
        name = "Grafana"
        rewrite_rule {
            name          = "NewRewrite"
            rule_sequence = 100

            request_header_configuration {
                header_name  = "Host"
                header_value = "{var_host}"
            }
            request_header_configuration {
                header_name  = "X-Real-IP"
                header_value = "{var_client_ip}"
            }
            request_header_configuration {
                header_name  = "X-Forwarded-For"
                header_value = "{var_add_x_forwarded_for_proxy}"
            }
            request_header_configuration {
                header_name  = "X-Forwarded-Host"
                header_value = "{var_host}"
            }
            request_header_configuration {
                header_name  = "X-Forwarded-Proto"
                header_value = "http"
            }
            request_header_configuration {
                header_name  = "Authorization"
                header_value = "\"\""
            }
            request_header_configuration {
                header_name  = "X-WEBAUTH-USER"
                header_value = "{var_client_user}"
            }
        }
    }
    
    depends_on = ["azurerm_virtual_network.network", "azurerm_public_ip.publicip"]
}
