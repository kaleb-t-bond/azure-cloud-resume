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
    name = "kalebtbcloudresume2026"
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
    value = azurerm_storage_account.resume_storage.primary_web_endpoint
}


# =============================================================================
# View Counter Backend
# =============================================================================

# --- Cosmos DB Account ---
# WHY COSMOS DB?
#   Azure Cosmos DB is a fully managed, globally distributed NoSQL database.
#   It's the industry standard for this pattern (the "Cloud Resume Challenge") because:
#   - It requires zero server management (fully serverless on the data layer)
#   - It scales automatically and supports global replication with a few clicks
#   - Free tier gives 1,000 RU/s + 25 GB at no charge (RU = "Request Unit", Cosmos DB's billing unit)
#
# NOTE: Azure allows only one free-tier Cosmos DB account per subscription.
# If you already have one, remove the 'free_tier_enabled' line.
resource "azurerm_cosmosdb_account" "resume_cosmos" {
  # WHY A DIFFERENT NAME?
  #   "kaleb-resume-cosmos" was stuck in a failed provisioning state in East US.
  #   Azure holds the name even for failed accounts, blocking recreation.
  #   Renaming sidesteps the reservation entirely.
  name                = "kaleb-resume-nosql"
  location            = azurerm_resource_group.resume_rg.location
  resource_group_name = azurerm_resource_group.resume_rg.name
  offer_type          = "Standard"

  # 'GlobalDocumentDB' = the SQL/Core API — lets you query documents with SQL-like syntax
  # This is Cosmos DB's most common and feature-rich API
  kind = "GlobalDocumentDB"

  free_tier_enabled = true

  # WHY SESSION CONSISTENCY?
  #   Cosmos DB offers 5 consistency levels (a distributed systems concept).
  #   'Session' is the default and most practical: a user always reads their own writes
  #   within a session. For a view counter, this is perfectly sufficient.
  consistency_policy {
    consistency_level = "Session"
  }

  # WHY WEST US 2 INSTEAD OF EAST US?
  #   East US is currently at capacity for new Cosmos DB accounts.
  #   The resource group is still in East US (resource groups are just management
  #   containers — they don't need to match the data region).
  #   West US 2 is a stable, well-provisioned region with no current capacity issues.
  #   zone_redundant = false prevents Azure from defaulting to Availability Zones,
  #   which have even more restrictive regional capacity limits.
  geo_location {
    location          = "West US 2"
    failover_priority = 0
    zone_redundant    = false
  }
}

# --- Cosmos DB Database ---
# A Cosmos DB account can hold multiple databases.
# Think of it like a server instance that can host multiple logical databases.
resource "azurerm_cosmosdb_sql_database" "resume_db" {
  name                = "resume-db"
  resource_group_name = azurerm_resource_group.resume_rg.name
  account_name        = azurerm_cosmosdb_account.resume_cosmos.name
}

# --- Cosmos DB Container ---
# A container is equivalent to a "table" in relational databases.
# It holds the JSON documents (our counter document).
#
# WHY PARTITION KEY '/id'?
#   Cosmos DB distributes data across physical partitions using the partition key.
#   Since we only have one counter document (id = "page-views"), using '/id' as
#   the partition key is the simplest valid choice — all reads/writes go to one partition.
#
# WHY THROUGHPUT 400?
#   400 RU/s is the minimum provisioned throughput. For a resume with low traffic,
#   this is more than enough. Each document read costs ~1 RU; each write costs ~5-10 RU.
resource "azurerm_cosmosdb_sql_container" "counters" {
  name                = "counters"
  resource_group_name = azurerm_resource_group.resume_rg.name
  account_name        = azurerm_cosmosdb_account.resume_cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.resume_db.name
  partition_key_paths = ["/id"]
  throughput          = 400
}

# --- Azure Static Web App (Free Tier) ---
# WHY SWITCH FROM AZURE FUNCTIONS TO STATIC WEB APPS?
#   Azure Static Web Apps (SWA) is a single free resource that bundles two things:
#   1. Global CDN-based static content hosting (serves index.html)
#   2. A managed serverless API backend (Azure Functions) built in
#
#   The critical difference: SWA's managed Functions quota is owned and managed by
#   Microsoft, completely separate from your subscription's App Service quota.
#   This means the "Dynamic VMs: 0" restriction on your subscription does NOT apply.
#
# WHY CAN WE REMOVE func_storage, resume_plan, AND resume_func?
#   Those three resources were required to manually manage the App Service compute layer.
#   SWA handles all of that internally — you just point it at your code and it runs.
#   This results in fewer resources, lower complexity, and the same end result.
#
# WHY EAST US 2 INSTEAD OF EAST US?
#   SWA only supports a specific set of management regions, and "East US" is not one of them.
#   "East US 2" is the nearest supported region. The actual content is always served from
#   Azure's global CDN regardless of which management region you pick, so performance
#   is identical for end users.
resource "azurerm_static_web_app" "resume_swa" {
  name                = "kaleb-resume-swa"
  resource_group_name = azurerm_resource_group.resume_rg.name
  location            = "East US 2"
  sku_tier            = "Free"
  sku_size            = "Free"

  # App settings are environment variables injected into the managed API (Azure Functions).
  # The Python function reads these at runtime — the values never appear in source code.
  app_settings = {
    # The Cosmos DB connection string: read from Terraform's computed attribute on the
    # Cosmos DB account resource, then injected securely into the function's environment.
    "COSMOS_CONNECTION_STRING" = azurerm_cosmosdb_account.resume_cosmos.primary_sql_connection_string

    # Required to activate the Python v2 programming model (the decorator-based style
    # used in api/function_app.py). Without this flag, the runtime won't find the function.
    "AzureWebJobsFeatureFlags" = "EnableWorkerIndexing"
  }
}

# The live URL of the Static Web App.
# After 'terraform apply', update the FUNCTION_URL constant in index.html to:
#   https://<default_host_name>/api/view-counter
output "swa_url" {
  value = "https://${azurerm_static_web_app.resume_swa.default_host_name}"
}

# The deployment token — authenticates GitHub Actions to push code to this SWA.
# Marked 'sensitive' so it never prints in plain text during 'terraform apply'.
# Retrieve it with: terraform output -raw swa_deployment_token
output "swa_deployment_token" {
  value     = azurerm_static_web_app.resume_swa.api_key
  sensitive = true
}

# The Cosmos DB endpoint — useful for verifying the resource in the Azure Portal.
output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.resume_cosmos.endpoint
}

