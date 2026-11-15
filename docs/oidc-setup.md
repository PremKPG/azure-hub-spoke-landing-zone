# Pipeline identity setup (OIDC)

GitHub Actions authenticates to Azure with workload identity federation. GitHub presents a signed token, Entra ID checks it against a federated credential, and issues a short-lived access token. No client secret is created or stored.

Run these in Bash. On Git Bash for Windows, set `MSYS_NO_PATHCONV=1` first so `/subscriptions/...` paths aren't rewritten.

## 1. Create the identity

```bash
export MSYS_NO_PATHCONV=1

SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
STATE_SA=$(az storage account list -g rg-tfstate-uks --query "[0].name" -o tsv)

APP_ID=$(az ad app create --display-name "gh-landing-zone" --query appId -o tsv)
az ad sp create --id "$APP_ID" -o none
```

## 2. Assign permissions

```bash
az role assignment create --assignee "$APP_ID" --role "Contributor" \
  --scope "/subscriptions/$SUB_ID" -o none

# Required for policy assignments and the custom role definition.
# In production, replace with a custom role limited to these actions.
az role assignment create --assignee "$APP_ID" --role "User Access Administrator" \
  --scope "/subscriptions/$SUB_ID" -o none

az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show -n "$STATE_SA" -g rg-tfstate-uks --query id -o tsv)" -o none
```

## 3. Add federated credentials

The subject must match exactly what GitHub presents. Newer repositories use immutable IDs:

```
repo:<owner>@<owner-id>/<repo>@<repo-id>:pull_request
repo:<owner>@<owner-id>/<repo>@<repo-id>:environment:production
```

Find the IDs from `https://api.github.com/users/<owner>` and `https://api.github.com/repos/<owner>/<repo>` (the `id` field), or from the subject quoted in an `AADSTS700213` error.

```bash
SUBJECT_BASE="repo:<owner>@<owner-id>/<repo>@<repo-id>"

for CRED in "gh-pull-request:pull_request" "gh-env-production:environment:production"; do
  NAME="${CRED%%:*}"
  SUFFIX="${CRED#*:}"
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"$NAME\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"$SUBJECT_BASE:$SUFFIX\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
done
```

## 4. Configure GitHub

- Repository secrets: `AZURE_CLIENT_ID` (`$APP_ID`), `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- Environment `production` with required reviewers
- Ruleset on `main`: require a pull request and the `Terraform plan` and `Security scan` status checks

## Troubleshooting

| Error | Cause |
|---|---|
| `AADSTS700213` / `AADSTS70021` no matching federated identity record | Subject mismatch: check owner, repo, IDs and environment name |
| OIDC token request fails | Workflow is missing `permissions: id-token: write` |
| `403` on `terraform init` | Missing Storage Blob Data Contributor on the state account |
| `AuthorizationFailed` on policy or role resources | Missing User Access Administrator, or assignment not yet propagated |
