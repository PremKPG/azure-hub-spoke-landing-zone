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