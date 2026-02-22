# Azure Cloud Resume Deployment 

**Live Site:** [Click here to view my live cloud resume!](https://kalebtbcloudresume2026.z13.web.core.windows.net)

## Project Overview
This project serves as a live, cloud-hosted version of my professional resume. Rather than manually clicking through the Microsoft Azure Portal to provision resources, I engineered this environment utilizing Infrastructure as Code (IaC). 

The architecture provisions a secure, cost-optimized static website hosted on an Azure Storage Account, demonstrating practical proficiency in cloud infrastructure, state management, and command-line deployments.

## Technology Stack
* **Cloud Provider:** Microsoft Azure
* **Infrastructure as Code (IaC):** Terraform (HCL)
* **Frontend:** HTML5, CSS3
* **Scripting & Deployment:** Azure CLI, PowerShell

## Cloud Architecture
The Terraform configuration (`main.tf`) handles the declarative deployment of the following Azure resources:
1. **Azure Resource Group:** Acts as the logical lifecycle and management boundary for the project to control the blast radius.

2. **Azure Storage Account:** Configured with Locally Redundant Storage (LRS) to ensure high availability across multiple physical server racks while remaining cost-optimized (Standard tier).

3. **Static Website Configuration:** A standalone resource enabling direct HTTP routing to the `index.html` file without requiring dedicated compute virtual machines.

## Deployment Lifecycle

### 1. Infrastructure Provisioning
The backend "hardware" is deployed via Terraform using the Azure CLI for local session token delegation (Credential-less Configuration).

```powershell
# Initialize the Terraform working directory and download the azurerm provider
terraform init

# Review the execution plan and dependency graph validation
terraform plan

# Provision the Azure resources
terraform apply
```

### 2. Artifact Deployment
Once the infrastructure state is locked and the endpoint is generated, the frontend build artifact (`index.html`) is pushed directly to the hidden $web container utilizing the Azure CLI and an idempotent overwrite flag.

```powershell
# Authenticate and upload the static HTML file
az storage blob upload -f index.html -c "`$web" --account-name kalebtbcloudresume2026 --auth-mode key --overwrite
```
## Author
**Kaleb Bond**

* Computer Science Graduate

* [LinkedIn](https://www.linkedin.com/in/kaleb-t-bond/)

* [GitHub](https://github.com/kaleb-t-bond)