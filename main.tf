# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

# create resource group
resource "azurerm_resource_group" "test" {
  name     = "tstHiaslTerraformStart"
  location = "West Europe"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "myTFVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "West Europe"
    resource_group_name = azurerm_resource_group.test.name
}

# create subnet in vnet
resource "azurerm_subnet" "servers" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# create a public IP
resource "azurerm_public_ip" "extWEB" {
  name                = "extWEB"
  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  allocation_method   = "Static"
}

# create a NIC in vnet subnet servers
resource "azurerm_network_interface" "webserver" {
  name                = "internal"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.extWEB.id}"
  }
}

# create windows VM
resource "azurerm_windows_virtual_machine" "webserver" {
    name                  = "webserver-vm"
  location              = azurerm_resource_group.test.location
  resource_group_name   = azurerm_resource_group.test.name
  network_interface_ids = [azurerm_network_interface.webserver.id]
  size               = "Standard_F2"
  admin_username      = "localadmin"
  admin_password      = "Edi.Stoiber!"
  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }



}

# create a network security group
resource "azurerm_network_security_group" "nsgExtWEB" {
  name                = "nsgExtWEB"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  security_rule {
    name                       = "http"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "RDP-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    # ssh muß auf für filecopy für UNIX
    security_rule {
    name                       = "AllowSSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    # winRM muß auf für filecopy auf Windows
    security_rule {
    name                       = "AllowWinRM"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# associate NSG with network interface <- das wirft keinen Fehler, tut aber auch nicht gleich beim Ersten mal was es soll. OHNE VERÄNDERUNG beim zweiten Mal klappt es !??!??!
resource "azurerm_network_interface_security_group_association" "NSGonWebServer" {
  network_interface_id      = azurerm_network_interface.webserver.id
  network_security_group_id = azurerm_network_security_group.nsgExtWEB.id
}

# i want to install some roles & features with terraform - e.g. IIS und WinRM (wird für das kopieren der files für die website genutzt)
# powershell: Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools
# we use virtual machine custom script extension
# IIS installieren
resource "azurerm_virtual_machine_extension" "vm_extension_install_iis" {
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.webserver.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true
  
  
  protected_settings = <<PROTECTED_SETTINGS
    {
<<<<<<< HEAD
      "commandToExecute": "powershell.exe -Command \"./webserverconfigure.ps1; exit 0;\""
=======
        
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools",
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted netsh advfirewall firewall add rule name=\"WinRM-HTTP\" dir=in localport=5985 protocol=TCP action=allow",
      "commandToExecute": "powershell -Command \"winrm set winrm/config/service '@{AllowUnencrypted=\\\"true\\\"}'",
      "commandToExecute": "powershell -Command \"winrm set winrm/config/service/auth '@{Basic=\\\"true\\\"}'"
>>>>>>> db69eddd5dba0bd58338415d4e9f5436d932ed5c
    }
  PROTECTED_SETTINGS

<<<<<<< HEAD
  settings = <<SETTINGS
    {
        "fileUris": [
          "https://github.com/mrachel2/terraformwebservice/blob/main/webserverconfig.ps1"
        ]
    }
  SETTINGS
}

=======

}
>>>>>>> db69eddd5dba0bd58338415d4e9f5436d932ed5c

# jetzt will ich aus meinem github eine Datei auf den webserver nach c:\inetpub\wwwroot kopieren - helloworld.html
# offenbar wird dafür in Unix SSH genutzt, auf windows winRM. Das muß auch in der NSG auf sein!
resource "null_resource" remoteExecProvisionerWFolder {
  provisioner "file" {
    source      = "helloworld.html"
    destination = "/inetpub/wwwroot/helloworld.html"
  }
  connection {
    host     = "${azurerm_public_ip.extWEB.ip_address}"
    type     = "winrm"
    user     = "localadmin"
    password = "Edi.Stoiber!"
    agent    = "false"
  }
  depends_on = [
    azurerm_network_security_group.nsgExtWEB,
    azurerm_virtual_machine_extension.vm_extension_install_iis,
    azurerm_virtual_machine_extension.enableWinRM_basicAuth,
    azurerm_virtual_machine_extension.enableWinRM_unencrypted,
    azurerm_virtual_machine_extension.configureWinRM
  ]
}
# Beispiel: https://github.com/jmassardo/Azure-WinRM-Terraform/blob/master/WindowsServer.tf
