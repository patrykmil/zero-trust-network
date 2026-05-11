locals {
  vm_api_base = <<EOF
#cloud-config
timezone: __TIMEZONE__
write_files:
  - path: /opt/api/main.py
    content: |
      from datetime import datetime
      import uvicorn
      from fastapi import FastAPI
      from requests import get
      app = FastAPI()
      PEER_IP = "__PEER_IP__"
      def get_remote_time():
          return get(f"http://{PEER_IP}:8000/time").text.strip('"')
      def get_local_time():
          return datetime.now().isoformat()
      @app.get("/")
      async def root():
          return {"remote_time": get_remote_time(), "local_time": get_local_time()}
      @app.get("/time")
      async def time():
          return get_local_time()
      if __name__ == "__main__":
          uvicorn.run(app, host="0.0.0.0", port=8000)
runcmd:
  - [apt-get, update]
  - [apt-get, install, -y, python3-pip]
  - [pip3, install, fastapi, uvicorn, requests]
  - [python3, /opt/api/main.py]
EOF

  vm_a_user_data = replace(
    replace(local.vm_api_base, "__PEER_IP__", azurerm_public_ip.vm_b.ip_address),
    "__TIMEZONE__", "Europe/Warsaw",
  )
  vm_b_user_data = replace(
    replace(local.vm_api_base, "__PEER_IP__", azurerm_public_ip.vm_a.ip_address),
    "__TIMEZONE__", "Asia/Tokyo",
  )
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location_a
}

resource "azurerm_virtual_network" "vnet_a" {
  name                = "vnet-a-unsecure"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "vnet_b" {
  name                = "vnet-b-unsecure"
  location            = var.location_b
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "a" {
  name                 = "snet-a"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet_a.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "b" {
  name                 = "snet-b"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet_b.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vm_a" {
  name                = "pip-vm-a-unsecure"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "vm_b" {
  name                = "pip-vm-b-unsecure"
  location            = var.location_b
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg_a" {
  name                = "nsg-a-wide-open"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "nsg_b" {
  name                = "nsg-b-wide-open"
  location            = var.location_b
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "a" {
  subnet_id                 = azurerm_subnet.a.id
  network_security_group_id = azurerm_network_security_group.nsg_a.id
}

resource "azurerm_subnet_network_security_group_association" "b" {
  subnet_id                 = azurerm_subnet.b.id
  network_security_group_id = azurerm_network_security_group.nsg_b.id
}

resource "azurerm_network_interface" "vm_a" {
  name                = "nic-vm-a-unsecure"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.a.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_a.id
  }
}

resource "azurerm_network_interface" "vm_b" {
  name                = "nic-vm-b-unsecure"
  location            = var.location_b
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.b.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_b.id
  }
}

resource "azurerm_linux_virtual_machine" "vm_a" {
  name                            = "vm-a-unsecure"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location_a
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  user_data                       = base64encode(local.vm_a_user_data)

  network_interface_ids = [
    azurerm_network_interface.vm_a.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "vm_b" {
  name                            = "vm-b-unsecure"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = var.location_b
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  user_data                       = base64encode(local.vm_b_user_data)

  network_interface_ids = [
    azurerm_network_interface.vm_b.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
