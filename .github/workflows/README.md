# CI/CD: Build & Deploy to Azure App Service

This workflow builds a Docker image from the repo root `Dockerfile`, pushes it to Azure Container Registry, and deploys it to the Linux App Service defined in `infra/`.

## Prerequisites

1. **Deploy infrastructure first** using the Bicep templates in `infra/`.
2. **Create a service principal** with the **AcrPush** role on the ACR and the **Contributor** role (or **Website Contributor**) on the App Service. Generate the JSON credential output:
   ```bash
   az ad sp create-for-rbac --name "github-actions-sp" \
     --role contributor \
     --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP> \
     --json-auth
   ```

## Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | Full JSON output from the `az ad sp create-for-rbac --json-auth` command |

## Required GitHub Variables

| Variable | Description | Example |
|---|---|---|
| `ACR_NAME` | ACR resource name (not the full login server) | `acrzavastoredevabc123` |
| `WEBAPP_NAME` | App Service name | `app-zavastore-dev-abc123` |

Set these under **Settings → Secrets and variables → Actions** in your GitHub repository.
