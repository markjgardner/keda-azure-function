variable "ClusterName" {
  description = "The name to use for your K8s cluster and associated resources (must be DNS safe)"
  default = "mykedak8s"
}

variable "Region" {
  description = "The azure region in which the resources should be provisioned"
  default = "EastUS2"
}

provider "azurerm" {
}

provider "azuread" {
}


resource "azurerm_resource_group" "rg" {
  name = "keda-rg"
  location = "${var.Region}"
}

resource "azuread_application" "sp-app" {
  name                       = "kedasp"
  homepage                   = "https://localhost"
  identifier_uris            = ["https://keda"]
  reply_urls                 = ["https://reply"]
  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
}

resource "azuread_service_principal" "sp" {
  application_id = "${azuread_application.sp-app.application_id}"
}

resource "azuread_service_principal_password" "sp-pass" {
  service_principal_id = "${azuread_service_principal.sp.id}"
  value = "${uuid()}"
  end_date = "${timeadd(timestamp(), "8760h")}"  //now + 1 year

  lifecycle {
    ignore_changes = [
      "value",
      "end_date"
    ]
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name = "${var.ClusterName}"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  dns_prefix = "${var.ClusterName}"

  agent_pool_profile {
    name = "pool1"
    count = 1
    vm_size = "Standard_DS2_v2"
    os_type = "Linux"
    os_disk_size_gb = "60"
  }

  service_principal {
    client_id = "${azuread_service_principal.sp.application_id}"
    client_secret = "${azuread_service_principal_password.sp-pass.value}"
  }
}

resource "azurerm_container_registry" "acr" {
  name                     = "${var.ClusterName}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  sku                      = "Standard"
  admin_enabled            = false
}

resource "azurerm_role_assignment" "acrpull" {
  scope = "${azurerm_container_registry.acr.id}"
  role_definition_name = "AcrPull"
  principal_id = "${azuread_service_principal.sp.id}"
}


resource "azurerm_storage_account" "storage" {
  name = "${var.ClusterName}sa"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_queue" "queue" {
  name = "keda-queue"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  storage_account_name = "${azurerm_storage_account.storage.name}"
}

provider "helm" {
  kubernetes {
    host = "${azurerm_kubernetes_cluster.aks.kube_config.0.host}"
    client_key = "${base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)}"
    client_certificate = "${base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)}"
  }
}

resource "helm_release" "keda_chart" {
  name = "keda"
  repository = "https://kedacore.azureedge.net/helm"
  chart = "keda-edge"
  namespace = "keda"
  devel = true
}