# Learning Log

Notes from building an Azure hub-and-spoke landing zone with Terraform and GitHub Actions.

## Lesson 1: The big picture
- A landing zone is the foundation (networking, security, governance) built before workloads arrive.
- Hub-and-spoke: shared services (firewall, Bastion, logging, DNS) in the hub; workloads isolated in spokes.
- VNet peering is NOT transitive: prod and dev are both peered to the hub but can't reach each other directly.
- Central Log Analytics gives one place to query and correlate events across every spoke.
  Cost is per GB ingested, so one workspace isn't cheaper; the win is visibility.
- Terraform is declarative: describe the end state, and Terraform works out the steps.

## Lesson 2: Git workflow
- Git tracks files, not folders: empty folders never reach GitHub (and shouldn't in a portfolio repo).
- .gitignore keeps state files, the .terraform folder and secrets off GitHub.
- main is protected by a ruleset: every change goes through a branch and pull request.
- Branch protection matters even solo: it's standard practice, stops untested changes reaching main
  (which will later mean reaching Azure), and gives every change a documented reason.
- Conventional Commits prefixes: feat, fix, docs, chore, ci.

## Lesson 3: Terraform basics and remote state
- Workflow: init → plan → apply. Always read the plan before applying.
- Provider type is inferred from the resource type prefix (azurerm_resource_group → azurerm).
- Drift: changes made in the portal show up in the next plan; the code is the source of truth.
- "-/+ forces replacement" means destroy and recreate, so always check plans for it.
- Losing the state file makes Terraform try to recreate everything.
- Remote state in Azure Storage: Entra ID auth (no shared keys), blob versioning, lease locking.
- The state storage account is created by a bootstrap script (Terraform can't create its own backend).
- .terraform.lock.hcl is committed so everyone uses the same provider version.
- Version constraints: ~> 4.0 allows 4.x updates but not 5.0 (breaking changes).

## Lesson 4: Hub network
- Modules are reusable building blocks with inputs (variables) and outputs.
- count = var.toggle ? 1 : 0 switches expensive resources on and off (cost control).
- Azure requires exact subnet names: AzureFirewallSubnet, AzureFirewallManagementSubnet, AzureBastionSubnet.
- Firewall Basic needs a separate management subnet and public IP.
- Resource references (e.g. azurerm_virtual_network.hub.name) let Terraform work out build order.

## Lesson 5: Spokes, peering and routing
- One spoke module + for_each builds both prod and dev.
- Peering must be created in both directions.
- Route table (UDR) 0.0.0.0/0 → firewall private IP forces all egress and spoke-to-spoke traffic
  through the firewall.
- NSG allows SSH only from the Bastion subnet; firewall + NSG = defence in depth.
- Route table count uses the boolean toggle, not the firewall IP (the IP isn't known at plan time).
- Real-world VM deployment errors:
  - SkuNotAvailable = Azure capacity (the region is out of that size).
  - Quota exceeded = my subscription's per-family vCPU limit (Basv2 was 0).
  - Fixed by checking `az vm list-usage` and `az vm list-skus`, then using Standard_D2s_v3.
  - Lesson: VM size should be a variable, not hard-coded.
- Terraform is idempotent: after a partial failure, re-running apply only creates what's missing.
- Proved the design: VM egress IP = firewall public IP, BBC blocked, Ubuntu allowed,
  prod → dev timed out, effective routes show 0.0.0.0/0 → 10.0.0.4.
- Environment variables (export) only last for one terminal session.
- Paste long text into the editor, not the terminal (heredoc EOF gotcha).

## Lesson 6: Private endpoints and DNS
- A private endpoint is a NIC with a private IP in my VNet, connected to a PaaS service.
- public_network_access_enabled = false closes the public route entirely.
- Same FQDN, different answer depending on where you ask:
  laptop → 51.x.x.x (public, blocked); VM in linked VNet → 10.1.2.4 (private).
- CNAME chain: kv.vault.azure.net → kv.privatelink.vaultcore.azure.net → private A record.
- private_dns_zone_group creates the A record automatically.
- DNS zones are centralised in the hub and linked to every VNet.
- Key Vault has two independent locks: RBAC (identity) and network access (defence in depth).
- count can switch a whole module on and off.
- Bastion creation timed out after 30 min ("context deadline exceeded" = Terraform stopped
  waiting, not necessarily an Azure failure). Never Ctrl+C a running apply.
- az vm run-command runs scripts inside a VM through the Azure agent, with no SSH or Bastion needed.
- Orphaned resource: Bastion finished in Azure after Terraform timed out, so it was never
  recorded in state. Destroy failed on the attached public IP. Fixed by deleting the Bastion
  with az CLI, then re-applying. Alternative: terraform import to adopt it.

  ## Lesson 7: Governance
- Azure Policy enforces rules at deployment time; Deny blocks, Audit only flags.
- Built-in policies looked up with data sources by display name (no hard-coded GUIDs).
- Scope matters: allowed locations and required tags at subscription level;
  "no NIC public IPs" only on spoke RGs, because the hub needs public IPs.
- The built-in "Allowed locations" policy ignores resource groups; tested with a VNet instead.
- Deny only affects new/updated resources. Existing ones are flagged as non-compliant;
  fixing them needs Modify/DeployIfNotExists + remediation.
- Compliance view flagged pre-existing resources (Azure auto-created RGs without owner tags).
- Microsoft Defender for Cloud auto-assigns a security baseline initiative (ASC Default).
- Custom RBAC role = least privilege: exact action strings, no write/delete.
- Activity log exported to Log Analytics for a central audit trail.
- terraform plan -out=tfplan + apply tfplan guarantees you apply exactly what you reviewed.

## Lesson 8: CI/CD with GitHub Actions and OIDC
- PR → Checkov scan + terraform plan (posted as a PR comment) → merge → manual approval
  (production environment) → terraform apply in GitHub.
- OIDC workload identity federation: GitHub presents a signed token, Entra ID checks it against
  a federated credential (issuer + subject + audience) and issues a short-lived access token.
  No client secrets to store, leak or rotate.
- Federated credential subjects are strict. Newer GitHub repos use immutable IDs:
  repo:Owner@<owner-id>/repo@<repo-id>:pull_request. Debugged AADSTS700213 by reading
  the presented subject in the error.
- Two credentials: pull_request (plans) and environment:production (applies).
- permissions: id-token: write is required for OIDC.
- concurrency group prevents parallel applies against the same state.
- Lock file needs linux_amd64 hashes for Linux runners (terraform providers lock).
- Required status checks: nothing merges to main unless the plan and scan succeed.
- Rule: plan locally, apply only through the pipeline.
- Path-filtered workflows + required status checks = PRs that never finish waiting.
  Fixed by running the plan workflow on every PR.