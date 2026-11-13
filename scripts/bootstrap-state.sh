#!/usr/bin/env bash
# Creates the storage account that holds Terraform state. Run once.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # stops Git Bash mangling /subscriptions/... paths

LOCATION="uksouth"
RG="rg-tfstate-uks"
SA="sttfstate$(openssl rand -hex 4)"   # must be globally unique
CONTAINER="tfstate"

az group create -n "$RG" -l "$LOCATION" --tags owner=prem -o none

az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false -o none

# Keep old versions of the state file (an undo button)
az storage account blob-service-properties update \
  --account-name "$SA" -g "$RG" --enable-versioning true -o none

# Give yourself access using your Entra ID login (no storage keys)
SA_ID=$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee "$ME" \
  --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none

echo "Waiting 60s for permissions to kick in..."
sleep 60
az storage container create -n "$CONTAINER" \
  --account-name "$SA" --auth-mode login -o none

echo "Done. storage_account_name = $SA"