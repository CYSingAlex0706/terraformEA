resource "random_pet" "prefix" {}

provider "azurerm" {
  features {
      resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
 subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "resource-aks" {
  name     = "resource-aks"
  location = "East Asia"

  tags = {
    environment = "Demo"
  }
}

resource "azurerm_resource_group" "rg" {
  name      = "azure-network-resource"
  location  = "East Asia"
}

# Create virtual network
resource "azurerm_virtual_network" "tfnetwork" {
  name                = "TF_Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "snet" {
  for_each = var.subnets
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.tfnetwork.name
  name = each.value["name"]
  address_prefixes = each.value["address_prefixes"]
}

resource "azurerm_route_table" "example" {
  name                          = "example-route-table"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "10.1.0.0/16"
    next_hop_type  = "VnetLocal"
  }

  tags = {
    environment = "Production"
  }
}

# Create public IPs
resource "azurerm_public_ip" "tf_public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

#Create load balancing
resource "azurerm_lb" "lb" {
  name                = "LoadBalancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.tf_public_ip.id
  }
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "PublicIPAddress"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "tf_nsg" {
  name                = "Network_SG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
}


# Create network interface
resource "azurerm_network_interface" "tf_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id = values(azurerm_subnet.snet)[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.tf_nic.id
  network_security_group_id = azurerm_network_security_group.tf_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_account" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "tf_vm" {
  name                  = "myVM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.tf_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_account.primary_blob_endpoint
  }
}

# Create sql server
resource "azurerm_mssql_server" "db_server" {
  name                         = "sql-server${random_id.randomId.hex}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "admin123"
  administrator_login_password = "p@sswordword123"

  tags = {
    environment = "demo"
  }
}

# Create storage_account for sql database
resource "azurerm_storage_account" "sql_storage_ac" {
  name                     = "sql${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create sql database
resource "azurerm_mssql_database" "db" {
  name           = "sql-db"
  server_id      = azurerm_mssql_server.db_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  read_scale     = false
  sku_name       = "S0"
  zone_redundant = false

  tags = {
    environment = "demo"
  }

}