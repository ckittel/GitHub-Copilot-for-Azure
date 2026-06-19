# East-west review

Traffic among the workload's own resources: virtual-network-to-virtual-network within the workload (peerings, hub-spoke), subnet-to-subnet, service-to-service, pod-to-pod, and any lateral path an attacker who already has a foothold inside the workload could use. No subnet is more trusted than any other.

The goal is to answer: "If one workload component is compromised, what else can it reach, on what ports, and what stops it?"

Before walking lateral paths in step 2 below, you must have completed [SKILL.md](../SKILL.md) step 6 (Learn grounding) for every component family in the inventory. The checks in this file frame the procedure (what to look for, in what order, with what severity); the authoritative source for each check is Microsoft Learn. If a check here conflicts with current Learn guidance, Learn wins. See [learn-grounding.md](./learn-grounding.md) for the precedence rules.

## Step 1. Build the connectivity graph before looking for findings

For the provided IaC, enumerate:

1. **Virtual networks and subnets**: address space, subnet purpose. For each subnet, assign a purpose tag from the classifier in [subnet-purposes.md](./subnet-purposes.md). The purpose tag is mandatory; an `unclassified` tag is allowed. Each subnet becomes one row in the report's [Subnets table](../assets/report-template.md#subnets); the tag itself is internal and stays in the scratch file, but the `Notes` column must translate it into a plain-English phrase so the reader understands what the skill thought the subnet is for.
2. **Virtual network peerings**: for each, capture `allowForwardedTraffic`, `allowGatewayTransit`, `useRemoteGateways`, `allowVirtualNetworkAccess`. Note hub-spoke topology if present. Also tag each peering's `remoteVirtualNetwork.id` as `in-scope` (the target virtual network is defined in the provided IaC), `trust-statement:<id>` (the target is declared by a `tr:` from step 4), or `unresolved` (the target is neither in the IaC nor covered by any trust statement). The `unresolved` tag is what step 2's "Unresolved remote endpoints" check keys off; do not skip it.
3. **Route tables (UDRs)**: which subnets they apply to, what next-hops they define, whether they force traffic through a firewall. Also tag each non-default route's next-hop as `in-scope`, `trust-statement:<id>`, or `unresolved` using the same scheme as peerings. A `nextHopType: VirtualAppliance` with a `nextHopIpAddress` that is not the IP of any NIC in the inventory and not claimed by a trust statement is `unresolved`; so is a `nextHopType: VirtualNetworkGateway` when no gateway is in the inventory and no `tr:platform-er-vpn` is declared. `nextHopType: Internet` and `nextHopType: None` (used as a blackhole) are not `unresolved`; they are their own checks.
4. **NSGs**: which subnets or NICs they apply to. Whether they reference ASGs or hard-coded CIDRs.
5. **Private Endpoints**: the resource targeted, the subnet they sit in, the private DNS zone they integrate with, and the sub-resource each `groupId` represents. Track each `privateLinkServiceConnections` value and the target it points to.
6. **Private DNS zones and virtual network links**: which zones are linked to which virtual networks. A missing link means silent fallback to public DNS.
7. **Virtual network DNS server settings**: for every virtual network in the IaC, capture `dhcpOptions`. Azure DNS and a controlled resolver in the inventory are acceptable, or it must be covered by `tr:platform-dns`. Hub virtual networks typically resolve through default Azure DNS by design.
8. **Service Endpoints**: which subnets, which services.
9. **AKS network model**: `networkPlugin`, `networkPolicy`, `privateCluster`, `apiServerAccessProfile.authorizedIpRanges`, pod subnet vs node subnet. The API server is the control plane; pod/service traffic is the data plane.
10. **PaaS firewalls**: for each PaaS resource with a network ACL or firewall in the inventory, capture `publicNetworkAccess`, the firewall's default action, `bypass`, and the allowed virtual networks/subnets. The exact property names vary by service.

Record the graph as: nodes (subnets, PaaS instances, private endpoints) and edges (peerings, NSG-allowed flows, private endpoint bindings, DNS resolutions). Mark every edge with its plane. Use a markdown table per virtual network.

## Step 2. Walk lateral paths

For each subnet, ask yourself: "what other subnets/resources can a component here reach, on what ports, and on which plane?" Compare against what it needs to reach.

As you walk, populate the Network lines-of-sight inventory in the report (see [report-rules.md](./report-rules.md#network-lines-of-sight)). Every allowed lateral, ingress, or egress flow becomes one row in that table. The inventory is the deliverable for paths the IaC permits but whose *intent* you cannot judge from the IaC. The checks below produce two kinds of output: **categorical defects** (rules broken regardless of intent -- file as findings) and **line-of-sight rows** (paths whose intent the user must confirm -- file in the inventory). Each check below labels which it produces.

### Segmentation (data plane)

- Default NSG posture: does each subnet have an NSG with a final rule denying VirtualNetwork-to-VirtualNetwork traffic (or an equivalent deny)? Pure reliance on Azure's default rules means any-to-any within the virtual network on any port.
- ASG usage: are workloads grouped by ASG so rules are intent-based? Hard-coded CIDR rules for intra-virtual-network flows are a red flag for drift.
- Cross-subnet flows: every cross-subnet flow the IaC permits becomes one row in the Network lines-of-sight inventory. The user confirms intent per row in SKILL.md step 10.
- Cross-virtual-network via peering: if `allowVirtualNetworkAccess: true` and no NSG denies, the `VirtualNetwork` service tag covers peered space, so flows are wide open.

### Subnet-purpose NSG expectations (data plane)

For every subnet, use the purpose tag captured in step 1 to look up the per-purpose expectations table in [subnet-purposes.md](./subnet-purposes.md#2-per-purpose-nsg-expectations) and compare against the IaC. Emit one finding per deviation; cite the row in the table and the per-service Microsoft Learn source that backs it.

These expectations exist because the generic segmentation checks above do not catch them. They are the kinds of rule that depend on the *purpose* of a subnet, not on its connectivity graph: outbound denied entirely on subnets that should not initiate egress, administrative-protocol inbound restricted to a single named source rather than the whole virtual network, and platform-required inbound the segmentation check does not know about. The [per-purpose expectations table](./subnet-purposes.md#2-per-purpose-nsg-expectations) is the source of truth for what each purpose requires.

When a subnet is `unclassified`, emit an Info finding rather than guessing.

### PaaS firewalls (data plane)

For every PaaS resource with a network ACL or firewall in the inventory, walk the following principles. The property names vary by service.

- **Public access plus a private endpoint is not automatically safe.** The private endpoint adds a private path; it does not typically remove the public one. If the IaC declares a private endpoint, public network access must be disabled on the same resource.
- **`defaultAction: Allow` means the firewall is off.** Must be `Deny` with explicit allows for the consumers the workload genuinely has.
- **Any `bypass` value extends trust to an entire class of Azure traffic, not just the workload's dependencies.** The default posture is the most restrictive value the service supports. Look up the service's network ACL / firewall reference page on Microsoft Learn and treat any value as a finding unless the IaC shows a concrete consumer in the same template that requires it. When a bypass is justified, the finding becomes Info and the Remediation requires resource-instance rules (where the service supports them) so the bypass is scoped to specific resources instead of all Azure services. Use your judgment based on the IaC: if the template does not show a consumer that needs the bypass, the bypass is unjustified and the finding stands.

### Private endpoints + DNS (data plane)

- Every private endpoint must have a private DNS zone link to *every virtual network that needs to resolve it*. The private endpoint configuration alone is incomplete without the DNS layer.
- Centralized DNS: if there is a hub-DNS pattern, confirm the spoke virtual networks have the zone linked or use the hub's DNS via custom DNS servers.
- Private endpoint network policies on the subnet (`privateEndpointNetworkPolicies` / `privateLinkServiceNetworkPolicies`): must be `Enabled` (or the granular `NetworkSecurityGroupEnabled` / `RouteTableEnabled` values) so the subnet NSG and UDRs apply to the private endpoint NIC. `Disabled` is a finding.

### Control plane reachable from workload subnets

- **AKS API server**: from which subnets is the API server reachable? In a private cluster, only subnets linked to the API server's private DNS zone (or those with `apiServerAccessProfile.authorizedIpRanges` matching their egress IPs) should reach it. A pod or VM that should never touch the cluster control plane reaching it is a finding even when it cannot authenticate today, because credential theft and the control-plane network reach are separable risks.
- **PaaS service-specific control-plane sub-resources**: per the per-service Microsoft Learn lookup required in [SKILL.md step 6](../SKILL.md#6-ground-each-component-family-in-microsoft-learn), some PaaS expose their control surface as a distinct FQDN; others bundle data and management onto one FQDN. For every resource in the inventory, capture which subnets can reach each resources control-plane and treat reach from a subnet with no legitimate need as a finding.

### Container east-west

- **Network policy.** `networkPolicy` on the AKS resource must be set. Without it, the cluster has no network policy enforcement and all pod-to-pod traffic is allowed regardless of what manifests get deployed later.
- **Actual `NetworkPolicy` resources (manifests).** Enabling the engine is necessary but not sufficient: until at least one `kind: NetworkPolicy` resource is deployed in a namespace, the default is still allow-all *in that namespace*. K8s NetworkPolicy manifests usually live outside the AKS IaC (Helm charts, Kustomize overlays, GitOps repos), so the provided path alone typically cannot prove the runtime posture. If the path does not contain sufficent `kind: NetworkPolicy` manifests, emit a finding and prompt the user per the `tr:k8s-network-policies` row in [dependencies.md](./dependencies.md#conditional-prompts).
- **Pod identity / IMDS reachability.** Pods reaching `169.254.169.254` can pull node identity tokens; block unless required.
- **Cluster reach to the rest of the workload.** The cluster's egress to workload PaaS, peered virtual networks, and shared services is covered by the PaaS firewalls, segmentation, and peering subsections above; treat the cluster as one more component in those walks rather than re-walking the inventory from the cluster's perspective.

### Peering hygiene

For every peering captured in step 1, ask whether each flag the IaC sets is needed for the topology the workload actually has. Each one should be tied back to a concrete topological reason in the workload.

- `allowForwardedTraffic` should be off unless an NVA or Azure Firewall in the path forwards traffic the spoke needs to receive.
- Treat any spoke-to-spoke peering as a finding unless the workload explicitly justifies skipping the hub.
- Gateway-related flags (`allowGatewayTransit`, `useRemoteGateways`) should never be configured to allow more access than the workload needs.

### Unresolved remote endpoints (peering to nowhere, UDR to nowhere)

A peering whose remote virtual network is not in the IaC and not covered by a trust statement, or a UDR whose next-hop IP is not a NIC in the inventory and not covered by a trust statement, is an unresolved remote endpoint. You cannot tell from the IaC whether this is a legitimate dependency on a shared service the workload needs to act as a client to (a hub firewall, a platform-team DNS forwarder, a sibling workload's API), or an exfiltration path the architect did not realize they were enabling. Either way, the workload's reachable surface now includes something you cannot see.

For every `unresolved` peering or UDR next-hop captured in step 1 (items 2 and 3):

- Emit a **Finding** (not an inventory row -- the IaC itself is incomplete; this is not a line-of-sight question for the user to confirm). One finding per unresolved remote.
  - **Default severity: Medium.** The path exists; the workload's east-west boundary is not closed.
  - **Promote to High** when any of: the peering has `allowForwardedTraffic: true` or `allowVirtualNetworkAccess: true` (or `allowVirtualNetworkAccess` defaulted to `true` and no NSG denies); a workload subnet on a sensitive tier (`data-tier`, `private-endpoint-only`, any subnet hosting Key Vault / SQL / Storage consumers) has line-of-sight via the peering or route to the unresolved remote; the UDR sends `0.0.0.0/0` to the unresolved next-hop (the entire workload's egress is leaving via something the review cannot inspect).
  - **Promote to Critical** when the unresolved peering combines `allowForwardedTraffic: true` with line-of-sight from a sensitive-tier subnet, or when the unresolved UDR forces all egress to an unknown NVA and the workload subnet hosts data the review classified as Critical-defect-worthy in another finding (PaaS without a private endpoint, Storage with sensitive containers, etc.).
- **Remediation**: name the remote, declare who owns it and what the workload uses it for, and either (a) bring the remote into the IaC so the reviewer can see what is on the other side, (b) declare a trust statement in step 4 (`tr:peering-<name>` or `tr:udr-<name>`) naming the owning team, the remote's purpose for the workload, and the controls the owning team applies on their side, or (c) remove the peering / route if it is not needed. The remediation must also tighten the peering flags (`allowForwardedTraffic: false`, `allowVirtualNetworkAccess: false` unless the workload genuinely acts as a client to the remote) and add an NSG deny on the workload side for any port the workload does not need to send to that destination.
- **Reachable from**: phrase as `Unresolved remote: <remote vnet id or next-hop IP>` so the reader sees what they did not declare.
- **Issue text** must include verbatim: "The IaC exposes a path to a remote endpoint that is neither defined in scope nor declared as a trust statement. The skill cannot tell whether this is an intended client relationship to a shared service or an exfiltration path. Treat as the latter until the workload owner declares it."
- **Open Questions**: add one entry per unresolved remote with the question "Who owns `<remote>` and what does the workload need to send to or receive from it? If platform-supplied, declare as `tr:peering-<name>` / `tr:udr-<name>`. If unused, remove from IaC."

A workload may legitimately have several unresolved remotes (multi-spoke hub-and-spoke patterns, shared platform services). That is fine; each one becomes its own finding until the user declares it. Do not collapse multiple unresolved remotes into a single finding -- the reader needs each one named so it can be triaged individually.

### Observability for east-west

Every filtering control in the inventory should be paired with a diagnostic setting that ships rule hits to a Log Analytics workspace, and that log stream must feed a detector that converts unusual traffic into an alert. A control whose decisions are not logged cannot be audited after an incident. Missing flow logs and missing rule-hit logs are findings against the resources that should be producing them.

## Step 3. Test the "blast radius" hypothesis

Pick the highest-value asset reachable east-west and trace backwards twice, once per plane:

- Data plane: list every subnet, identity, and service that can reach the asset on its data port. If that list is larger than the components that legitimately need to, that is the lead finding.
- Control plane: list every subnet from which the asset's control surface can be mutated. If a workload component can mutate the security configuration of another component it does not own, that is the lead finding instead.

Repeat for every other resource in the workload.

## Step 4. Write findings

Use the [report rules](./report-rules.md). Send categorical defects to the [Findings section](./report-rules.md#findings); send paths whose intent you cannot judge from IaC to the [Network lines-of-sight](./report-rules.md#network-lines-of-sight) section as ranked review rows for the user to resolve in SKILL.md step 10.

### Categorical defects

These are always Findings, regardless of whether the path was "intended."

- **Critical**
  - `defaultAction: Allow` on PaaS firewalls
  - AKS without `networkPolicy`
  - spoke-to-spoke peering bypassing the hub firewall
  - `bastion-target` or `jumpbox` subnet with administrative-protocol inbound reachable from `Internet`
  - `aks-pod` subnet without a subnet NSG
  - unresolved peering with `allowForwardedTraffic: true` and line-of-sight from a sensitive-tier subnet
  - unresolved UDR `0.0.0.0/0` next-hop
- **High**
  - NSG missing or misconfigured on a workload subnet (excluding the platform-exempt subnets listed in [defense-in-depth.md](./defense-in-depth.md#subnets-where-the-nsg-requirement-is-waived-or-constrained)), including any deviation from the per-purpose expectations in [subnet-purposes.md](./subnet-purposes.md#2-per-purpose-nsg-expectations)
  - admin ports allowed across subnets without ASG-scoped justification
  - non-`None` `bypass` on a PaaS firewall with no consumer in the IaC that justifies it
  - private endpoint without private DNS zone link for a virtual network that resolves it
  - `publicNetworkAccess: Enabled` on PaaS that already has a private endpoint
  - AKS API server reachable from subnets that have no legitimate need
  - for services that expose a separately-reachable control-plane, the data has a private endpoint while the control-plane is left on the public endpoint
  - AKS with `networkPolicy` engine enabled but no `kind: NetworkPolicy` manifests in the provided path and no `tr:k8s-network-policies` trust statement declared
  - unresolved peering with `allowForwardedTraffic: true` or `allowVirtualNetworkAccess: true` (or defaulted-on with no NSG deny)
  - unresolved peering or UDR next-hop with line-of-sight from a sensitive-tier subnet
  - unresolved UDR sending `0.0.0.0/0` to an unknown next-hop
- **Medium**
  - hard-coded CIDR NSG rules where ASGs should be used
  - non-`None` `bypass` on a PaaS firewall without instance-rule scoping when the IaC shows a justifying consumer (unjustified bypass is High -- see the PaaS firewalls section)
  - missing flow logs / Traffic Analytics
  - subnet named to suggest one purpose (e.g., `snet-pe-*`) but containing other resource types
  - unresolved peering or UDR next-hop that does not meet the High criteria above
- **Low / Info**
  - subnet naming that hinders review
  - oversized subnets that complicate future segmentation
  - `unclassified` subnets where the classifier in [subnet-purposes.md](./subnet-purposes.md#1-classify-subnets) could not assign a purpose.

These exist as findings because the IaC itself is the defect; intent does not matter.

**Line-of-sight rows (Network lines-of-sight, not Findings):** any data-plane east-west path the IaC allows but that does not violate one of the categorical rules above. You cannot tell from IaC alone whether the path is the intended architecture or an over-permissive rule. File it in the inventory in the walk order defined in the [Network lines-of-sight section](./report-rules.md#network-lines-of-sight) of the report rules, with `Intended?` left blank. SKILL.md step 10 is where the user marks each row Y, N, or accepted-risk; N-rows graduate to Findings at that point.

**Control plane is always a finding, never an inventory row.** A workload subnet that can reach the a PaaS control plane goes to the Findings section regardless of "intent." The bar for the control plane is *no legitimate need*, not *user confirms unintended*.

**Reachable from (threat source).** Every east-west finding must name the attacker position explicitly in the `Reachable from` field per the [report rules](./report-rules.md). For this flow the source is almost always one of:

- `Adjacent subnet: <name>`: another subnet in the same virtual network whose NSG allows the flow (or no NSG exists). Name the subnet.
- `Peered virtual network: <name>` or `Peered virtual network: any spoke via hub`: when peering plus permissive NSG/route lets traffic in from another virtual network. Identify which virtual network(s) when possible.
- `Compromised workload in subnet <name>`: when the realistic attack starts from a code-execution foothold (RCE'd VM, compromised pod, malicious package in App Service). Use this for findings about PaaS data stores reachable from app subnets that have no need for them.
- `Compromised pod in <namespace> on cluster <name>`: AKS-specific form of the above; use when `networkPolicy` is missing or permissive.
- `Compromised managed identity in subnet <name>`: required for control-plane findings where the attack path is workload identity to ARM. Name the subnet whose workloads hold the identity and the resource(s) the identity can mutate.
- `On-prem (via ExpressRoute / VPN)`: use when on-prem ranges reach a workload subnet via the gateway and the allowed scope is broader than the workload needs.

The `Reachable from` source and the affected resource together must make the lateral path obvious in one read. "Reachable from: Adjacent subnet `snet-web`; Resource: `sql-orders` (1433)" tells the reader what packet would have been stopped. "Reachable from: an attacker" does not.

Every finding cites file:line(s), the affected plane (`Plane: data`, `control`, or `both`), the threat source (`Reachable from:`), the specific property to change, and the citations required by [learn-grounding.md](./learn-grounding.md): the MCSB control ID (NS-*) when one applies, plus at least one prescriptive Microsoft Learn URL.

## Apply to every candidate finding

Apply the [per-finding rules](./flow-analysis.md#per-finding-rules) to output from this flow analysis.
