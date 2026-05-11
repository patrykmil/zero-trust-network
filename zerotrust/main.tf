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
      import subprocess
      app = FastAPI()
      PEER_HOSTNAME = "__PEER_HOSTNAME__"
      def get_peer_ip():
          result = subprocess.run(["tailscale", "status"], capture_output=True, text=True)
          for line in result.stdout.splitlines():
              parts = line.split()
              if len(parts) >= 2 and PEER_HOSTNAME in parts[1]:
                  return parts[0]
          return None
      def get_remote_time():
          peer_ip = get_peer_ip()
          if peer_ip:
              try:
                  return get(f"http://{peer_ip}:8000/time", timeout=5).text.strip('"')
              except:
                  return "error"
          return "peer not found"
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
  - [curl, -fsSL, https://tailscale.com/install.sh, --output, /tmp/install-tailscale.sh]
  - [sh, /tmp/install-tailscale.sh]
  - [tailscale, up, --auth-key=__TAILSCALE_AUTH_KEY__, --hostname=__HOSTNAME__]
  - [sleep, 15]
  - [python3, /opt/api/main.py]
EOF

  vm_apply_common = replace(local.vm_api_base, "__TAILSCALE_AUTH_KEY__", var.tailscale_auth_key)

  vm_a_user_data = replace(
    replace(
      replace(local.vm_apply_common, "__PEER_HOSTNAME__", "vm-b-zt"),
      "__TIMEZONE__", "Europe/Warsaw"
    ),
    "__HOSTNAME__", "vm-a-zt"
  )

  vm_b_user_data = replace(
    replace(
      replace(local.vm_apply_common, "__PEER_HOSTNAME__", "vm-a-zt"),
      "__TIMEZONE__", "Asia/Tokyo"
    ),
    "__HOSTNAME__", "vm-b-zt"
  )
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location_a
}

resource "azurerm_virtual_network" "vnet_a" {
  name                = "vnet-a-zerotrust"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "vnet_b" {
  name                = "vnet-b-zerotrust"
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

resource "azurerm_network_security_group" "nsg_a" {
  name                = "nsg-a-zerotrust"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_group" "nsg_b" {
  name                = "nsg-b-zerotrust"
  location            = var.location_b
  resource_group_name = azurerm_resource_group.main.name
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
  name                = "nic-vm-a-zerotrust"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.a.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "vm_b" {
  name                = "nic-vm-b-zerotrust"
  location            = var.location_b
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.b.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_a" {
  name                            = "vm-a-zerotrust"
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
  name                            = "vm-b-zerotrust"
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
