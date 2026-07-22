# GitHub Actions OIDC setup

## What OIDC does

GitHub Actions requests a short-lived identity token when the Terraform workflow runs.

Microsoft Entra exchanges that token for Azure access. No Azure client secret is stored in GitHub.

## Workflow permissions

```yaml
permissions:
  contents: read
  id-token: write
```

## Identity used

The workflow uses a Microsoft Entra application registration and its service principal. A federated identity credential links that application to this GitHub repository.

## Federated credential

Use this issuer and audience:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`

The workflow runs for pull requests to `development` or `main`, and for manual runs. The workflow may require the following subjects, depending on the trigger used:

| Context | Subject |
| --- | --- |
| Pull request | `repo:<owner>/<repository>:pull_request` |
| Manual run from `development` | `repo:<owner>/<repository>:ref:refs/heads/development` |
| Manual run from `main` | `repo:<owner>/<repository>:ref:refs/heads/main` |

Only create the subjects used by the repository's configured workflow runs.

## Azure permissions

- `Contributor` on the target resource group allows Terraform to manage resources.
- `User Access Administrator` or `Role Based Access Control Administrator` is also required because Terraform creates role assignments.
- The Terraform identity also needs the Key Vault data-plane permission used by the certificate resource and must be allowed through the vault firewall while provisioning.

## GitHub settings

Configure these under **Settings → Secrets and variables → Actions**:

| Name | Type | Purpose |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | Secret | Application client ID |
| `AZURE_TENANT_ID` | Secret | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure subscription ID |
| `APIM_PUBLISHER_EMAIL` | Variable | APIM publisher email |

These values are identifiers rather than passwords, but the current workflow reads them from GitHub's secrets context. No client secret is created.

## Validation

1. Run the workflow from a pull request or manual dispatch.
2. Confirm the Azure login step succeeds.
3. Confirm no Azure client secret is stored in GitHub.
4. Confirm Terraform can read the target resource group.

## Troubleshooting

### No matching federated identity

Check that the issuer, audience, repository, and subject exactly match the workflow context.

### Authorisation failure

Check the service principal's resource-group role and its permission to create role assignments.

### Terraform plans all resources as new

A hosted runner starts without the workstation's Terraform state, so it may plan existing resources as new. A shared Azure Blob backend would allow CI to compare against the deployed state.

## Why OIDC

- No long-lived Azure client secret
- Short-lived tokens
- Access limited by GitHub claims and Azure RBAC
