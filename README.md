# Billing Auto Infrastructure Deployment

This directory contains the Bicep infrastructure as code for the Billing Auto application.

## Architecture

The deployment creates the following resources:

- **Azure Container Registry (ACR)**: For storing container images
- **PostgreSQL Flexible Server**: Database server with one database
- **Key Vault**: For storing secrets and configuration
- **Storage Account**: Blob storage
- **Container App Environment**: For hosting containerized applications
- **Log Analytics Workspace**: For logging and monitoring
- **Managed Identity**: User-assigned identity for resource access

## Prerequisites

- Existing Resource Group: `B2C-LYZR-BILLINGAUTO-RGRP`
- Existing VNet: `WTW-ITCOLT-DEV` with address space `10.58.52.0/26`
- Azure CLI installed and authenticated
- Appropriate permissions to deploy resources

## Deployment

### Using Azure CLI

```bash
# Deploy to the existing resource group
az deployment group create \
  --resource-group B2C-LYZR-BILLINGAUTO-RGRP \
  --template-file main.bicep \
  --parameters parameters.json
```

### What-If Validation

Before deploying, you can preview the changes:

```bash
az deployment group what-if \
  --resource-group B2C-LYZR-BILLINGAUTO-RGRP \
  --template-file main.bicep \
  --parameters parameters.json
```

## Network Configuration

The deployment creates two subnets in the existing VNet:

1. **containerAppSubnet** (`10.58.52.0/28`):
   - Delegated to Container Apps
   - Service endpoints for Key Vault and Storage

2. **dbSubnet** (`10.58.52.16/28`):
   - For database private endpoints
   - Private endpoint network policies disabled

## Parameters

All configuration is in `parameters.json`. Key parameters:

- **vnetName**: Name of the existing VNet
- **vnetResourceGroup**: Resource group containing the VNet
- **acrName**: Globally unique ACR name
- **pgServerName**: Globally unique PostgreSQL server name
- **storageAccountName**: Globally unique storage account name (3-24 lowercase chars)
- **databaseName**: Name of the PostgreSQL database to create

## Security Features

- PostgreSQL uses **Entra ID authentication only** (password auth disabled)
- Key Vault uses **RBAC authorization**
- Storage account **disables public blob access**
- Private endpoints for PostgreSQL
- Network ACLs restrict access to specific subnets
- Managed identity for secure resource access

## Outputs

The deployment outputs key resource identifiers:

- Managed Identity ID and Principal ID
- ACR login server
- PostgreSQL server FQDN and database name
- Key Vault name
- Storage account blob endpoint
- Container App Environment ID

## DNS Configuration

Private endpoint DNS records are automatically created by WTW automation within 5 minutes of deployment. Do not manually configure Private DNS Zones.

Reference: [WTW Private Endpoint Automation](https://wtw.sharepoint.com/sites/KnowledgeHub/SitePages/Private-Endpoint-Automation.aspx)

## Post-Deployment

After deployment:

1. Grant the managed identity necessary RBAC roles on ACR:
   ```bash
   az role assignment create \
     --assignee <managed-identity-principal-id> \
     --role AcrPull \
     --scope <acr-id>
   ```

2. Store application secrets in Key Vault

3. Configure container apps to use the environment

## Module Structure

```
billing-auto/
├── main.bicep                          # Main orchestration file
├── parameters.json                     # Configuration parameters
├── README.md                           # This file
└── modules/
    ├── acr.bicep                       # Azure Container Registry
    ├── postgresql.bicep                # PostgreSQL Flexible Server
    ├── keyvault.bicep                  # Key Vault
    ├── storage.bicep                   # Storage Account
    └── container-app-env.bicep         # Container App Environment
```

## Customization

To customize the deployment:

1. Edit `parameters.json` to change resource configurations
2. Modify individual module files in `modules/` for specific resource changes
3. Update `main.bicep` to add or remove resources
