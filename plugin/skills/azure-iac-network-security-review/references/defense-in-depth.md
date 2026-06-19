# Defense-in-depth layer rules

This file defines when the skill demands a second (or third) network control on top of an existing one, and when it does not. The IaC has many places where a second layer is possible; only some of those second layers are suggested.

A missing second layer is a finding only when it appears in the [Required pairs](#required-pairs) table below. Otherwise, recommending it is an overreach of this skill.

## Required pairs

For each pair, both controls must be present. Missing the second control is a finding scored per the flow procedure's severity rules, with the `Tradeoffs` field reflecting the additional operational burden of the second layer.

| Pair | Why both are required | Source to cite |
| :--- | :-------------------- | :------------- |
| **Private endpoint** + **`publicNetworkAccess: Disabled`** on the PaaS resource | A private endpoint adds a private path; it does not typically remove the public one. Leaving the public endpoint reachable while a private endpoint exists makes the private endpoint security-theater. | MCSB `NS-2` (Secure cloud native services with network controls); per-service Well-Architected Framework service guide. |
| **WAF policy** + **NSG on the AppGW** | WAF inspects L7; the NSG limits L3/L4 reach (sources, ports). | MCSB `NS-6` (Deploy web application firewall) + `NS-2`; Well-Architected Framework service guide for App Gateway. |
| **Azure Firewall as egress point** (UDR `0.0.0.0/0` to firewall) + **per-subnet NSGs** | The firewall enforces FQDN and L7 allowlists; the NSG enforces source/destination at the subnet boundary so an attacker who pivots inside the spoke still hits a deny. | MCSB `NS-3` (Deploy firewall at the edge of enterprise network) + `NS-1` (Establish network segmentation boundaries); Azure Firewall Well-Architected Framework service guide. |
| **AKS `networkPolicy` engine** + **at least one default-deny `kind: NetworkPolicy` per workload namespace** | The engine is the substrate; until a policy is deployed in a namespace, the default is still allow-all *in that namespace*. Policy manifests usually live outside the AKS IaC, so the manifest half is covered by the `tr:k8s-network-policies` trust statement in [dependencies.md](./dependencies.md#conditional-prompts); the engine half is always a direct finding. | MCSB `NS-1`; AKS Well-Architected Framework service guide. |
| **AKS `networkPolicy` engine** + **NSG on the AKS node subnet(s)** | The engine scopes pod-to-pod within the cluster; the NSG scopes node-subnet-to-everything-else (including the platform-required egress and any reach to PaaS data planes). Either alone leaves a class of lateral movement unfiltered. | MCSB `NS-1`; AKS Well-Architected Framework service guide. |
| **Hub firewall via UDR** (forced tunneling) + **spoke NSGs** | Hub firewall provides transit inspection; spoke NSGs provide spoke segmentation. Either alone leaves a class of lateral movement unfiltered. | MCSB `NS-1` + `NS-3`. |
| **DDoS Network Protection plan on the virtual network** + **WAF on the L7 public endpoint** | DDoS Network protects volumetric L3/L4 attacks; WAF inspects L7. Neither alone covers both layers. | MCSB `NS-5` (Deploy DDoS protection) + `NS-6`. |
| **App Service `ipSecurityRestrictions`** + **WAF in front (AppGW or Front Door)** when the app is public | IP restrictions deny early at the platform; WAF inspects payload. Skipping IP restrictions because "WAF is in front" assumes the WAF cannot be bypassed (it often can be by hitting the App Service default hostname). | MCSB `NS-2` + `NS-6`; App Service Well-Architected Framework service guide. |
| **Private endpoint** + **private DNS zone linked to every virtual network that resolves the private endpoint** | A private endpoint without a zone link silently falls back to public DNS and the public endpoint if still enabled. The private endpoint configuration alone is incomplete without the DNS layer. | MCSB `NS-2`; Private Endpoint reference docs (private DNS integration). |

### Reading the table

- Each row is a *finding rule*: if the IaC shows the first control without the second, emit one finding per occurrence.
- The finding's `Remediation` field names the second control with the exact property to set.
- The finding's `Tradeoffs` field must include the cost of the second layer (operational burden, additional policy/rule maintenance, etc.).
- The finding's `References` must include the MCSB control ID(s) from the right-hand column.

### Subnets where the NSG requirement is waived or constrained

Several pairs in the table above demand "NSG on the subnet." The Azure platform forbids NSGs on some subnets and constrains them on others; "missing NSG" on these subnets is not a finding (or is a finding with very different semantics). Check the subnet name and skip or adjust as noted before emitting any NSG-missing or NSG-pair finding.

| Subnet | NSG rule | Skill behavior |
| :----- | :------- | :------------- |
| `AzureFirewallSubnet`, `AzureFirewallManagementSubnet` | NSG attachment is not supported by the platform. The firewall enforces traffic policy itself. | Do not emit "NSG missing." Do not emit the Azure Firewall + spoke NSG pair finding *against this subnet*; the pair applies to the spoke workload subnets that route through the firewall, not to the firewall subnet itself. |
| `RouteServerSubnet` | NSG attachment is not supported. | Do not emit "NSG missing." |
| `GatewaySubnet` (VPN / ExpressRoute gateway) | Microsoft recommends against attaching one; misconfigured rules break gateway control traffic. | Do not emit "NSG missing." |
| `AzureBastionSubnet` | NSG is required by Microsoft guidance with a specific allowlist. | Emit a finding when the NSG is missing or when it is present but does not match the documented allowlist. Cite the Azure Bastion Well-Architected Framework service guide and the Azure Bastion NSG reference. |

## Same-layer alternatives

These are not defense-in-depth pairs; they are alternative ways to implement the *same* control at the same layer. Pick one; recommending the other on top of it is not a finding.

| Alternative | Preferred when both exist | Note |
| :---------- | :------------------------ | :--- |
| Subnet NSG vs NIC NSG | Subnet NSG. | If both exist, emit a finding if their rules conflict. Effective-rules ambiguity is operationally dangerous; converge on subnet NSG and remove the NIC NSG, or document and justify why both are needed. Do not file "no NIC NSG" as a finding when a subnet NSG already covers the workload. |
| NSG with hard-coded CIDRs vs NSG with ASGs | ASG-based rules. | Do not double-count: a "use ASGs" finding is one finding, not also a "missing second layer" finding. |

## Not a defense-in-depth layer (do not flag missing)

Do not flag the following common over-recommendations:

- **Tags on resources.** Tags are inventory metadata, not enforcement.
- **Diagnostic settings / flow logs.** Observability, not enforcement.
- **Defender for Cloud recommendations.** Detection, not preventative enforcement.
- **Service endpoint missing when a private endpoint is present (or vice versa).** Service endpoints and private endpoints solve different problems and are not substitutes.

## Workflow integration

- **While running the flow procedures** ([north-south.md](./north-south.md), [east-west.md](./east-west.md)): every check that touches a control listed in the [Required pairs](#required-pairs) table must also check for the partner control and emit a separate finding if the partner is missing.
- **In the finding's References**: include the MCSB control ID from the table plus the per-service Well-Architected Framework service guide Security section as the citation.
- **In the inventory**: when both halves of a required pair are present, note that in the inventory row so the next reviewer can see the pair was verified together.
