# Define the provider
terraform {
  required_providers {
    # 'azurerm' = Azure Resource Manager plugin
    azurerm = {
        # The source is hashicorp's official registry
        source = "hashicorp/azurerm"
        # Use any version from 3.x
        version = "~> 3.0"
    }
  }
}

# Initialize the plugin
provider "azurerm" {
    # Use standard defaults for Azure's behavior
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
    # "Standard" tier tells Azure to use HDDs instead of SSDs
    account_tier = "Standard"
    # 'LRS' = Locally Redundant Storage
    # How Azure handles hardware failures:
    # 'LRS' means 3 copies of data are stored on 3 distinct servers in the same data center
    account_replication_type = "LRS"
}

# Enable "Static Website" feature
# Handles HTTP requests w/o extra installs
# ** This method is deprecated, so is commented out in favor of the modern method below it
/*
static_website {
    index_document = "index.html"
}
*/

# Enable the "Static Website" feature (modern version)
resource "azurerm_storage_account_static_website" "resume_website" {
  storage_account_id = azurerm_storage_account.resume_storage.id
  # Serve clients who access the url with "index.html"
  index_document = "index.html"
}



# Output the URL
output "website_url" {
    value = azurerm_storage_account_static_website.resume_website.endpoint
}

