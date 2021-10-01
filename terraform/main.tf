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

# module "vnet" {
#   source              = "Azure/vnet/azurerm"

#   vnet_name = "${var.prefix}-vnet"

#   resource_group_name = azurerm_resource_group.architect.name
#   address_space       = ["10.0.0.0/16"]
#   subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#   subnet_names        = ["subnet1", "subnet2", "subnet3"]

#   subnet_service_endpoints = {
#     subnet2 = ["Microsoft.Storage", "Microsoft.Sql"],
#     subnet3 = ["Microsoft.AzureActiveDirectory"]
#   }

#   depends_on = [azurerm_resource_group.architect]

#   tags = local.tags
# }

# resource "azurerm_network_security_group" "ssh" {
#   name                = "${var.prefix}-ssh-security-group"
#   resource_group_name = azurerm_resource_group.architect.name
#   location            = azurerm_resource_group.architect.location

#   security_rule {
#     name                       = "${var.prefix}-ssh-rule"
#     priority                   = 100
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }

#   tags = local.tags
# }

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

  redis_configuration {
    # enable_authentication           = lookup(local.redis_config, "enable_authentication", null)
    # maxfragmentationmemory_reserved = lookup(local.redis_config, "maxfragmentationmemory_reserved", null)
    # maxmemory_delta                 = lookup(local.redis_config, "maxmemory_delta", null)
    # maxmemory_policy                = lookup(local.redis_config, "maxmemory_policy", null)
    # maxmemory_reserved              = lookup(local.redis_config, "maxmemory_reserved", null)
    # notify_keyspace_events          = lookup(local.redis_config, "notify_keyspace_events", null)
    # rdb_backup_enabled              = lookup(local.redis_config, "rdb_backup_enabled", null)
    # rdb_backup_frequency            = lookup(local.redis_config, "rdb_backup_frequency", null)
    # rdb_backup_max_snapshot_count   = lookup(local.redis_config, "rdb_backup_max_snapshot_count", null)
    # rdb_storage_connection_string   = lookup(local.redis_config, "rdb_storage_connection_string", null)
  }

  # lifecycle {
  #   ignore_changes = [redis_configuration[0].rdb_storage_connection_string]
  # }

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
