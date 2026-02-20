# Define the provider
terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 3.0"
    }
  }
}

provider "azurerm" {
    features {}
}

# Create a Resource Group
# (A logical "folder" for cloud stuff)
resource "azurerm_resource_group" "resume_rg" {
    name = "kaleb-resume-resources"
    location = "East US"
}

# Create a Storage Account
# (The "bucket/server" for files)
resource "azurerm_storage_account" "resume_storage" {
    # CRITICAL - "name" must be unique.
    # Azure Storage names share a global DNS namespace across the world
    name = "kalebtb9495cloudresume2026"
    resource_group_name = azurerm_resource_group.resume_rg.name
    location = azurerm_resource_group.resume_rg.location
    account_tier = "Standard"
    account_replication_type = "LRS"

    # Enable "Static Website" feature
    static_website {
      index_document = "index.html"
    }
}

# Output the URL
output "website_url" {
    value = azurerm_storage_account.resume_storage.primary_web_endpoint
}

