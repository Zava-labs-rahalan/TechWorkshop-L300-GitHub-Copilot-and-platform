# ZavaStorefront — Azure Infrastructure

## Overview

This folder contains the Bicep infrastructure-as-code (IaC) templates for the ZavaStorefront web application, designed for deployment with Azure Developer CLI (AZD).

All resources are provisioned into a **single resource group** in **westus3** (dev environment).

## Architecture

| Resource | Module | Purpose |
|---|---|---|
| Log Analytics Workspace | `modules/logAnalytics.bicep` | Centralized log collection |
| Application Insights | `modules/appInsights.bicep` | App monitoring and telemetry (workspace-based) |
| Azure Container Registry | `modules/acr.bicep` | Docker image storage (Basic SKU, admin disabled) |
| Linux App Service Plan | `modules/appService.bicep` | Hosts the Web App (B1 Basic tier) |
| Web App for Containers | `modules/appService.bicep` | Runs the .NET 6 containerized app |
| AcrPull Role Assignment | `modules/roleAssignment.bicep` | RBAC — Web App managed identity pulls from ACR |
| Azure AI Services | `modules/aiFoundry.bicep` | GPT-4 and Phi model deployments |
| AI Foundry Hub & Project | `modules/aiFoundry.bicep` | AI workspace for model experimentation |
| Storage Account | `modules/aiFoundry.bicep` | Dependency for AI Foundry Hub |
| Key Vault | `modules/aiFoundry.bicep` | Secrets management for AI Foundry Hub |

## Security Decisions

- **No admin credentials on ACR** — image pulls use Azure RBAC (AcrPull) via system-assigned managed identity
- **No local Docker required** — use `az acr build` or GitHub Actions for cloud-side image builds
- **Key Vault RBAC** — authorization via Azure RBAC (no access policies)
- **HTTPS only** — enforced on the Web App
- **Managed identities** — used for App Service and AI Foundry Hub

## Prerequisites

- Azure CLI (`az`) authenticated
- Azure Developer CLI (`azd`) installed
- An Azure subscription with sufficient quota in `westus3`

## Deployment

```bash
# Preview the deployment (recommended first step)
azd provision --preview

# Deploy everything (infra + app)
azd up
```

## File Structure

```
azure.yaml             # AZD project configuration
Dockerfile             # Multi-stage Docker build for the .NET 6 app
.dockerignore          # Files excluded from Docker build context
infra/
├── main.bicep         # Root orchestration template
├── main.bicepparam    # Bicep parameters (dev defaults)
├── README.md          # This file
└── modules/
    ├── logAnalytics.bicep      # Log Analytics Workspace
    ├── appInsights.bicep       # Application Insights
    ├── acr.bicep               # Azure Container Registry
    ├── appService.bicep        # App Service Plan + Web App
    ├── roleAssignment.bicep    # AcrPull RBAC role assignment
    └── aiFoundry.bicep         # AI Services, Hub, Project, models
```

## Cost Notes (Dev)

- **App Service Plan B1** — ~$13/month
- **ACR Basic** — ~$5/month
- **Log Analytics** — pay-per-GB ingested
- **Application Insights** — pay-per-GB ingested
- **AI Services S0** — pay-per-request for model inference
- **AI Foundry Hub Basic** — included with workspace, compute billed separately

## Building Images Without Local Docker

```bash
# Build and push using ACR Tasks (cloud-side)
az acr build --registry <acr-name> --image zava-storefront:latest .
```
