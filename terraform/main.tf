locals {
  tags = {
    ArchitectVersion = "1.0.0"
  }
}

resource "azurerm_resource_group" "architect" {
  name     = "${var.prefix}-azure-resource-group"
  location = "East US"

  tags = local.tags
}

module "linuxservers" {
  vm_hostname = "${var.prefix}-vm"

  source              = "Azure/compute/azurerm"
  resource_group_name = azurerm_resource_group.architect.name
  vm_os_simple        = "UbuntuServer" # TODO: pin to version
  public_ip_dns       = [var.prefix]
  vnet_subnet_id      = module.network.vnet_subnets[0]

  storage_account_type = "Standard_LRS"

  depends_on = [azurerm_resource_group.architect]

  # vm_size = "TODO"

  tags = local.tags
}

module "network" {
  vnet_name = "${var.prefix}-vnet"

  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.architect.name
  subnet_prefixes     = ["10.0.1.0/24"]
  subnet_names        = ["subnet1"]

  depends_on = [azurerm_resource_group.architect]

  tags = local.tags
}

data "azurerm_network_security_group" "vm_nsg" {
  name                = "architectryan-vm-nsg"
  resource_group_name = azurerm_resource_group.architect.name
}

resource "azurerm_network_security_rule" "ssh" {
  name                        = "${var.prefix}-ssh-rule"
  resource_group_name         = azurerm_resource_group.architect.name
  network_security_group_name = data.azurerm_network_security_group.vm_nsg.name

  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
}

resource "azurerm_redis_cache" "redis" {
  name                = "${var.prefix}-redis"
  location            = azurerm_resource_group.architect.location
  resource_group_name = azurerm_resource_group.architect.name

  family   = "C"
  sku_name = "Basic"

  enable_non_ssl_port = true # enable 6379
  shard_count         = 0
  capacity            = 1

  redis_version = 4

  depends_on = [
    module.network
  ]

  tags = local.tags
}

resource "azurerm_redis_firewall_rule" "redis_firewall_rule" {
  name = "${var.prefix}_redis_firewall_rule"

  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = azurerm_resource_group.architect.name

  start_ip = cidrhost(module.network.vnet_address_space[0], 0)
  end_ip   = cidrhost(module.network.vnet_address_space[0], -1)
}



// TODO: create private endpoint for redis
// TODO: private link service?
