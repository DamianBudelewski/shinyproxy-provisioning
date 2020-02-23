# Shinyapp deployment
Shiny is an R package that makes it easy to build interactive web apps straight from R. This project is all about deploying existing shiny app `NYC_Metro_Vis` link in description, usign Azure Cloud environment. 

Tools used in this project: 
* Terraform 
* Ansible 
* Docker 
* [Azure DevOps](https://dev.azure.com/damianbudelewski/shinyapp/)
* Azure Container Registry

URL of Azure Container Registry with app image: `shinyappsacr.azurecr.io/shinyapps/nycmetrovis`



### Links
* [Shiny app used in this project](https://github.com/CodingTigerTang/NYC_Metro_Vis)
* [Shiny proxy getting started documentation](https://www.shinyproxy.io/getting-started/)
* [Example of VM deployment using terraform](https://docs.microsoft.com/en-us/azure/terraform/terraform-create-complete-vm)
* [Terraform variables introduction](https://upcloud.com/community/tutorials/terraform-variables/)
* [Ansible deployment with Azure DevOps](https://www.azuredevopslabs.com/labs/vstsextend/ansible/)
