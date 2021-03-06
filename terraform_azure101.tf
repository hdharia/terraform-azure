# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
  environment     = "${var.environment}"
}

resource "azurerm_resource_group" "test" {
  name     = "docker_dev"
  location = "usgovvirginia"
}

resource "azurerm_virtual_network" "test" {
  name                = "docker_dev_vn"
  address_space       = ["10.0.0.0/16"]
  location            = "usgovvirginia"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
  name                 = "docker_dev_sub"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "test" {
  name = "docker_dev_ip"
  location = "usgovvirginia"
  resource_group_name = "${azurerm_resource_group.test.name}"
  public_ip_address_allocation = "dynamic"
  domain_name_label = "dockerdevhd"

  tags
  {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "test" {
  name                = "docker_devni"
  location            = "usgovvirginia"
  resource_group_name = "${azurerm_resource_group.test.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.test.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.test.id}"
  }
}

resource "azurerm_managed_disk" "test" {
  name                 = "datadisk_existing"
  location             = "usgovvirginia"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "test" {
  name                  = "docker_devvm"
  location              = "usgovvirginia"
  resource_group_name   = "${azurerm_resource_group.test.name}"
  network_interface_ids = ["${azurerm_network_interface.test.id}"]
  vm_size               = "Standard_DS1_v2"
  
  boot_diagnostics {
    enabled = "true"
    storage_uri = "https://linuxvm.blob.core.usgovcloudapi.net"
  } 


  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # Optional data disks
  storage_data_disk {
    name              = "datadisk_new"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "1023"
  }

  storage_data_disk {
    name            = "${azurerm_managed_disk.test.name}"
    managed_disk_id = "${azurerm_managed_disk.test.id}"
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = "${azurerm_managed_disk.test.disk_size_gb}"
  }

  os_profile {
    computer_name  = "${var.computer_name}"
    admin_username = "${var.admin_username}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys = [{
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.key_data}"
    },
    {
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${var.key_data_jenkins}"
    }]
  }

  tags {
    environment = "dev"
  }
}

resource "azurerm_virtual_machine_extension" "test" {
  name                 = "docker_install"
  location             = "usgovvirginia"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_machine_name = "${azurerm_virtual_machine.test.name}"
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
  {
    "fileUris": ["https://raw.githubusercontent.com/hdharia/terraform-azure/master/script/install-docker.sh"]
  }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "commandToExecute": "curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh"
  }
PROTECTED_SETTINGS


  tags {
    environment = "dev"
  }
}

data "azurerm_public_ip" "test" {
  name                = "${azurerm_public_ip.test.name}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  depends_on          = ["azurerm_virtual_machine.test"]
}