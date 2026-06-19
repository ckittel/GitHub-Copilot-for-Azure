# Network security review: <scope name>

- IaC source: `<path/to/folder>` (Bicep or Terraform)
- Review mode: <`Workload (full review).` \| `Components-only. <one-sentence description>`>
- Environment: production
- Reviewed at: <YYYY-MM-DD>

## Assumptions

- <one bullet per assumption that affects a finding; omit the section heading's content with `_None._` if there are none>

## Dependency claims

| ID   | Platform control the user attested to | Verified? |
| :--- | :------------------------------------ | :-------- |
| `tr:<id>` | <one sentence> | <`Y` \| `N (see Open questions #<n>)`> |

## Inventory summary

- **Ingress paths**: <count> (<short list>)
- **Egress paths**: <count> (<short list>)
- <counts of virtual networks, subnets, peerings, public IPs, PaaS resources with public surface, private endpoints, NSGs, route tables>

### Subnets

| Virtual network | Subnet | CIDR | NSG | UDR | Notes |
| :-------------- | :----- | :--- | :-- | :-- | :---- |
| <vnet name> | <subnet name> | <prefix> | <nsg name or `—`> | <route table name or `—`> | <one short phrase saying what the subnet is for, plus any delegation, service endpoint, or `privateEndpointNetworkPolicies` value worth surfacing> |

## Network lines-of-sight

| Source | Destination | Port / proto | Plane | Why this row is here | Intended? |
| :----- | :---------- | :----------- | :---- | :------------------- | :-------- |
| <source> | <destination> | <port>/<proto> | <data, control, both> | <one phrase> | _user to answer_ |

## Implicit IaC defaults

_No implicit defaults; every network-security-relevant property is set explicitly in the IaC._

## Findings

_No network-security findings._

## Open questions for the user

1. <numbered, blocking item>

## Suppressed by workload context

<!-- Populated only after the workload-refinement loop runs. Omit this section if it has not run. -->

## Out of scope

A standing reminder of what this skill does not review. Use a different tool to evaluate these concerns.

- **IAM and RBAC**, including managed-identity permissions and Microsoft Entra ID configuration.
- **Secrets and key management**: Key Vault access policies, secret hygiene, rotation.
- **Encryption at rest**: disk encryption, customer-managed keys, double encryption.
- **Application-layer authentication and authorization**: token validation, API scope enforcement, session handling.
- **Application code security**: input validation, dependency vulnerabilities, supply chain.
- **Cost, SKU sizing, and capacity.**
- **General recoverability and resiliency**, except where a network choice directly removes redundancy.

### Azure Resource Manager

ARM (`management.azure.com`) is a global multi-tenant service reachable from the Internet by default. What stops malicious modification to your resources is Microsoft Entra ID and RBAC, both out of scope. A compromised system or human identity with contributor rights can call ARM from anywhere, regardless of network security controls on your workload's network.
