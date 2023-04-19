output "resource_group_name_aks" {
  value = azurerm_resource_group.resource-aks.name
}

output "resource_group_name_network" {
  value = azurerm_resource_group.rg.name
}

output "virtual_network_name" {
  value = azurerm_virtual_network.tfnetwork.name
}

output "subnet_id" {
  value = { for snet in azurerm_subnet.snet : snet.name => snet.id }
}

output "tf_public_ip_id" {
  value = azurerm_public_ip.tf_public_ip.id
}

output "tf_nsg_id" {
  value = azurerm_network_security_group.tf_nsg.id
}

output "tf_nic_id" {
  value = azurerm_network_interface.tf_nic.id
}

output "storage_account_name" {
  value = azurerm_storage_account.storage_account.name
}

output "example_ssh_public_key" {
  value = tls_private_key.example_ssh.public_key_openssh
}

output "tf_vm_id" {
  value = azurerm_linux_virtual_machine.tf_vm.id
}
