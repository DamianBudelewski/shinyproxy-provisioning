# Shinyapp deployment
Shiny is an R package that makes it easy to build interactive web apps straight from R. This project is all about deploying existing shiny app `NYC_Metro_Vis` link in description, usign Azure Cloud environment. 

Tools used in this project: 
* Terraform 
* Ansible 
* Docker 
* [Azure DevOps](https://dev.azure.com/damianbudelewski/shinyapp/)
* Azure Container Registry

## Deployment

### 1. Building application
URL of Azure Container Registry with app image: `shinyappsacr.azurecr.io/nycmetrovis`

### 2. Creating infrastructure 
Start with moving into terraform directory, then initialize project with `terraform init` cmd. You should see information similar to this `Terraform has been successfully initialized!`. Now you can create execution plan with `terraform plan` command. After a while you should see quite big output containing every resource that is planned to be deployed. In our case it's 9 resources `Plan: 9 to add, 0 to change, 0 to destroy`. Last what we have to do is to apply this plan with `terraform apply`. After successful deployment you should get public ip address and fqdn name of created virtual machine.

```bash
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

public_ip_address = 104.40.216.99
fqdn = nycvisshinyapp.westeurope.cloudapp.azure.com
```

### 3. Provisioning and application deployment
This step is fully automated with ansible playbooks. All you have to do, is to input variables from terraform to `ansible/hosts.yml` file and run `ansible-playbook -i hosts.yml deploy.yml`. This will prepare server with installation of shinyproxy, docker and ngixn with proper configuration. At the end, it will start shinyproxy and nginx service.

## TODO
- [ ] Ansible role for nginx deployment
- [ ] Configure terraform to parse output variables into ansible vars file.
- [x] Create Azure DevOps pipeline for building app and deploying image to ACR.
- [ ] Auth0.
- [ ] Nginx SSL Proxy.

## Links
* [Shiny app used in this project](https://github.com/CodingTigerTang/NYC_Metro_Vis)
* [Shiny proxy getting started documentation](https://www.shinyproxy.io/getting-started/)
* [Example of VM deployment using terraform](https://docs.microsoft.com/en-us/azure/terraform/terraform-create-complete-vm)
* [Terraform variables introduction](https://upcloud.com/community/tutorials/terraform-variables/)
* [Ansible deployment with Azure DevOps](https://www.azuredevopslabs.com/labs/vstsextend/ansible/)
* [OAuth authentication](https://auth0.com/blog/adding-authentication-to-shiny-server/)
