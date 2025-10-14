variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

variable "resource_group_name" {
  default = "aks-rg"
}
variable "location" {
  default = "eastus"
}
variable "aks_cluster_name" {
  default = "cheap-aks-cluster"
}
