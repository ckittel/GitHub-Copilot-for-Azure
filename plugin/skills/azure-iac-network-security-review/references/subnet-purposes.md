# Subnet-purpose classification and NSG expectations

NSG must match what this subnet is for. For example, a private-endpoint-only subnet does not legitimately initiate outbound traffic. A Bastion target subnet should accept SSH/RDP only from `AzureBastionSubnet`. A jumpbox subnet should not be reachable from anywhere except management entry points.

This file defines:

- The classifier that infers each subnet's purpose from what is deployed into it.
- The per-purpose NSG expectations for inbound and outbound, against the IaC is compared.
- The finding mapping: which findings are important, at what severity, with what citation.

The classifier is the skill's own opinion built on per-service Microsoft Learn guidance; the expectations table cites the prescriptive sources. See [learn-grounding.md](./learn-grounding.md) for the source precedence and excluded sources.

## 1. Classify subnets

Infer the purpose of each subnet from its contents and naming, in this order (first match wins). A subnet may match multiple rules; the first match determines the expectations.

| Order | Purpose tag | Match rule |
| ----: | :---------- | :--------- |
| 1 | `azure-firewall` | Subnet named `AzureFirewallSubnet` or `AzureFirewallManagementSubnet`. |
| 2 | `route-server` | Subnet named `RouteServerSubnet`. |
| 3 | `gateway` | Subnet named `GatewaySubnet`. |
| 4 | `bastion-host` | Subnet named `AzureBastionSubnet`. |
| 5 | `apim-{internal,external}` | Subnet hosts `Microsoft.ApiManagement/service`; capture the mode from `virtualNetworkType` (`Internal` or `External`). |
| 6 | `appgw` | Subnet hosts `Microsoft.Network/applicationGateways`. |
| 7 | `aks-node-pool` | Subnet referenced by an `AgentPoolProfile.vnetSubnetID`. |
| 8 | `aks-pod` | Subnet referenced by `AgentPoolProfile.podSubnetID` (Azure CNI pod-subnet mode). |
| 9 | `appservice-vnet-integration` | Subnet has a delegation to `Microsoft.Web/serverFarms`. |
| 10 | `container-apps-environment` | Subnet has a delegation to `Microsoft.App/environments`. |
| 11 | `container-instances` | Subnet has a delegation to `Microsoft.ContainerInstance/containerGroups`. |
| 12 | `aks-internal-loadbalancer` | Subnet referenced by a Kubernetes `Service` of type `LoadBalancer`. Detected from a manifest file when present; otherwise inferred from context where no AKS `AgentPoolProfile` references, but it sits in an virtual network containing, and has no compute deployed into it. |
| 13 | `private-endpoint-only` | Subnet contains **only** `Microsoft.Network/privateEndpoints` NICs. Network policies on the subnet may be `Enabled` or `Disabled`; the purpose is the same. |
| 14 | `bastion-target` | Subnet hosts VMs/VMSS that are reachable on 22/3389 only from the virtual network's `AzureBastionSubnet` (verify by checking the existing NSG rule or by inferring from a hub-spoke architecture where Bastion lives in the hub). |
| 15 | `jumpbox` | Subnet hosts VMs/VMSS named `jumpbox*`, `mgmt*`, `admin*` and the subnet is reachable from a Bastion or has only a few VMs. |
| 16 | `dns-resolver-inbound` | Subnet has a delegation to `Microsoft.Network/dnsResolvers` and is referenced by a `Microsoft.Network/dnsResolvers/inboundEndpoints` child resource. |
| 17 | `dns-resolver-outbound` | Subnet has a delegation to `Microsoft.Network/dnsResolvers` and is referenced by a `Microsoft.Network/dnsResolvers/outboundEndpoints` child resource. |
| 18 | `databricks-{public,private}` | Subnet has a delegation to `Microsoft.Databricks/workspaces` (capture which of the pair). |
| 19 | `data-tier` | Subnet hosts a managed DB service that injects a NIC (Azure SQL Managed Instance delegated subnet `Microsoft.Sql/managedInstances`, PostgreSQL Flexible Server delegated subnet `Microsoft.DBforPostgreSQL/flexibleServers`, MySQL Flexible Server delegated subnet `Microsoft.DBforMySQL/flexibleServers`). |
| 20 | `nat-gateway-shared` | Subnet associated only with a `Microsoft.Network/natGateways` (no compute) and used as a SNAT egress aggregator. |
| 21 | `build-agents` | Subnet hosts CI/CD build agents: VMs, VMSS, or AKS environments named `runner*`, `gh-runner*`, `actions-runner*`, `ado-agent*`, `devops-agent*`, `jenkins*`, `agent*`, `build*`, `ci*`, or whose tags/IaC comments identify them as self-hosted GitHub Actions runners, Azure DevOps self-hosted agents, Jenkins agents, GitLab runners, or equivalent. |
| 22 | `generic-workload-tier` | Default. Subnet hosts general workload compute that doesn't match a more specific rule. |

When the classifier is uncertain, label the subnet `unclassified` in the inventory and emit an finding noting the unclassified subnet with the IaC `file:line(s)`. Do not silently fall through to `generic-workload-tier`; the unclassified state is itself useful signal for the SKILL.md step 10 conversation.

## 2. Per-purpose NSG expectations

For each purpose, the table below states the expected inbound posture, the expected outbound posture. Deviations from the expectation are findings; judge severity based on workload context. Where the table calls for no traffic on a direction, the subnet NSG must carry an explicit `Deny *` rule from `*` to `*` at a low priority on that direction. Relying on the platform default to deny is a security finding.

| Purpose | Expected inbound | Expected outbound | Notes |
| :------ | :--------------- | :---------------- | :---- |
| `azure-firewall` | Platform-controlled. | Platform-controlled. | NSG associations on `AzureFirewallSubnet` are silently disabled by the platform; having one is not a security issue. |
| `route-server` | Platform-controlled. | Platform-controlled. | NSG association on `RouteServerSubnet` is not supported; having one is a supportability issue, not a security issue. |
| `gateway` | Platform-controlled. | Platform-controlled. | NSGs are not supported on `GatewaySubnet` for either VPN or ExpressRoute gateways; associating one may cause the gateway to stop functioning. See [ExpressRoute virtual network gateways](https://learn.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways#gateway-subnet) and [VPN Gateway settings](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings). |
| `bastion-host` | From platform-required sources only. | To `VirtualNetwork` on 22/3389, plus platform-required endpoints. | Exact required inbound/outbound rules at [Bastion NSG](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg). |
| `apim-internal` | From `VirtualNetwork` on 443, plus platform-required endpoints. | To backends on backend ports, plus platform-required endpoints. | Inbound from `Internet` defeats the point of Internal mode. Full required-port list at [APIM VNet reference](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-reference). |
| `apim-external` | From `Internet` on 443, plus platform-required endpoints. | To backends on backend ports, plus platform-required endpoints. | External APIM should sit behind WAF/Application Gateway for OWASP coverage; see [north-south.md](./north-south.md). Full required-port list at [APIM VNet reference](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-reference). |
| `appgw` | From `Internet` on listener ports (typically just 443), plus platform-required endpoints. | To backend pool targets on backend ports, plus platform-required endpoints. | Full required-port list at [Application Gateway infrastructure configuration](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure). |
| `aks-node-pool` | From AppGW/ILB subnets and the AKS control plane on app ports; no admin ports from anywhere. | To required egress via Azure Firewall (UDR `0.0.0.0/0` to firewall); none otherwise. | Required outbound FQDNs at [AKS outbound rules](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress). |
| `aks-pod` | From node subnet on app ports. | Same posture as the node pool. | Pod-layer NetworkPolicy is the primary control; subnet NSG is coarser. See [defense-in-depth.md](./defense-in-depth.md#required-pairs). |
| `appservice-vnet-integration` | None. | To app dependencies on dependency ports. | App Service originates traffic from this subnet; it does not listen on it. See [report-rules.md](./report-rules.md#out-of-scope) for the control-plane note. |
| `container-apps-environment` | From client IPs on app ports. | To app dependencies on dependency ports, plus platform-required endpoints. | External workload-profile environments route inbound through a managed public IP outside this subnet, so subnet NSG cannot filter inbound for them. Full required-port list at [Container Apps NSG rules](https://learn.microsoft.com/en-us/azure/container-apps/firewall-integration#nsg-allow-rules). |
| `container-instances` | From explicit consumer subnets on container ports. | To app dependencies on dependency ports. | - |
| `aks-internal-loadbalancer` | From the upstream L7 subnet on the service's listener port(s); from `AzureLoadBalancer` on the health-probe port(s). | None. | Allowing any other inbound source (e.g., the full `VirtualNetwork`) or any outbound rule wider than `Deny *` is a finding because no workload component legitimately listens on, or sends from, this subnet. |
| `private-endpoint-only` | From explicit consumer subnets/ASGs on the private endpoint's data port(s). | None. | Private endpoint NICs do not initiate outbound. The subnet NSG also applies to any non-private-endpoint NIC that lands in the subnet by mistake. `privateEndpointNetworkPolicies` must be `Enabled` (or the granular `NetworkSecurityGroupEnabled` / `RouteTableEnabled` values) so the NSG actually filters the private endpoint NIC; `Disabled` is a finding. |
| `bastion-target` | From the virtual network's `AzureBastionSubnet` prefix on 22/3389. | To app dependencies via the hub firewall. | Allowing the entire `VirtualNetwork` as a source defeats the point of fronting with Bastion. |
| `jumpbox` | From `AzureBastionSubnet` on 22/3389. | To target subnets on app ports; firewall-mitigated otherwise. | Same source-restriction rationale as `bastion-target`. |
| `dns-resolver-inbound` | From `VirtualNetwork` on 53/UDP and 53/TCP. | None. | The inbound endpoint answers queries; it does not initiate outbound DNS. |
| `dns-resolver-outbound` | None. | To upstream DNS server IPs on 53/UDP and 53/TCP. | Upstream IPs come from the forwarding ruleset. |
| `databricks-public` / `databricks-private` | Per Databricks reference. | Per Databricks reference. | Do not narrow further than Databricks requires; Databricks blocks deployment otherwise. See [Databricks VNet injection NSG rules](https://learn.microsoft.com/en-us/azure/databricks/security/network/classic/vnet-inject#network-security-group-rules). |
| `data-tier` | From app-tier ASGs on the DB port. | None. | SQL MI service-aided rules (prefixed `Microsoft.Sql-managedInstances_UseOnly_mi-`) are platform-managed; do not flag them as drift. |
| `nat-gateway-shared` | None. | None. | If non-NAT compute lands in this subnet, reclassify and re-check. |
| `build-agents` | None. Self-hosted runners poll out to the orchestrator; they should not listen. | To the orchestrator's endpoints, authorized package registries, authorized container registries, and the workload's deploy targets. No reachability to data planes except those the build pipeline legitimately needs, and those reach the data plane via private endpoints. | A compromised build agent inherits the agent's deploy identity and its egress; both are typically priviledged. |
| `generic-workload-tier` | From upstream tier ASGs on app ports; no admin ports across subnets. | To downstream tier ASGs on dependency ports; firewall-mitigated to Internet. | Inbound from `VirtualNetwork` on `*`, outbound `*` to Internet without a firewall UDR, and admin ports across subnets are the typical violations. |
| `unclassified` | Cannot judge. | Cannot judge. | Emit a row asking the user to clarify the subnet's purpose in SKILL.md step 10. |

Definitions:

- **Platform-required endpoints**: the specific service tags, IP ranges, ports, or FQDNs a managed service needs to function (control plane, health probes, telemetry, image pulls, etc.). The per-row Notes link to the Microsoft Learn page that enumerates them.
- **Admin ports**: remote-management and cluster-control ports like SSH, RDP, AKS API server, etc. These should never be reachable from outside their legitimate client subnets.

## 3. Workflow integration

- **SKILL.md step 2 (Inventory)**: capture the purpose tag for every subnet in the scratch file. Do not print it in the report's [Subnets table](../assets/report-template.md#subnets); translate it into a short, plain-English phrase in the `Notes` column instead.
- **east-west.md Step 2 (segmentation checks)**: after the existing segmentation checks, walk each subnet through its purpose's expectations from the table above and emit a finding for each deviation.
- **report-rules.md**: every subnet-purpose finding must simply explain, in the Issue text, what the subnet is for and why the deviation matters. Do not cite the purpose tag.
- **SKILL.md step 10 (refinement)**: `unclassified` subnets and any subnet whose purpose the user disputes are topics for [Workload refinement part 2](../SKILL.md#workload-refinement-part-2).

## Why this is opinionated

MCSB and Azure Well-Architected Framework says "segment with NSGs" and "deny by default"; it does not enumerate per-subnet rules. The combination above is the skill's interpretation of those general principles for the specific subnet roles Azure encourages. The purpose-aware aggregation is this skill's contribution.
