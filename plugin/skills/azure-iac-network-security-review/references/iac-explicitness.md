# IaC explicitness review

A network-security-relevant property that is not set explicitly in the IaC is a defect, regardless of whether the current Microsoft default is safe. The IaC must show its security intent.

This step produces its own class of findings, separate from north-south and east-west. It runs once over the full IaC inventory.

## Stance

- **Every network-security-relevant property must be set explicitly in the IaC.** "Relying on the Microsoft default" is not a security control.
- **IaC and Azure Policy are independent controls.** A `deny`-effect policy that enforces a property does not make the unset property in IaC acceptable: if the policy is later relaxed, scoped narrower, or fails to evaluate, the IaC's unset value is what deploys. Conversely, an explicit value in IaC does not waive the policy: if the IaC is later changed, the policy still catches drift. Each must stand on its own.
- **The current default does not change whether the finding is emitted.** Unset is unset.

## What "network-security-relevant" means

A property is in scope for this step when its value controls any of the following:

- Whether the resource is reachable from outside its subnet.
- Which source addresses, identities, virtual networks, subnets, or service tags may connect.
- Whether traffic transits a private path.
- What traffic gets routed where.
- What filtering or inspection sits in the path.
- What gets network traffic gets observed.
- What peerings or links extend the reachable surface.

If the property influences any of those, it is in scope. When in doubt, ask yourself: would a packet that was previously denied now reach the workload, or would a packet that was previously allowed now be denied? If the answer is no, the property is out of scope.

### Out of scope

- The property governs compute size, replication, cost, application configuration, or non-network features.
- A property living on a networking resource (App Gateway, Front Door, APIM, Azure Firewall, Load Balancer, virtual network, NIC) does not make it automatically in scope. Apply the criteria above; if none of them are satisfied, the property is out of scope no matter where it lives.
- Transport-protocol-version selection that does not change who can reach the listener. For example, HTTP/2 or HTTP/3 support, gRPC vs. REST listener mode, WebSocket enablement.
- Topology-determined virtual-network configuration. Properties whose correct value depends on the virtual network's role in the wider topology, not on the resource in isolation. Topology-determined properties are reviewed in the flow steps where role context is available, not here.

## How to derive the per-resource property set

Derive the in-scope property set per resource from Microsoft Learn at review time.

For each distinct resource type in the inventory:

1. Fetch the Bicep/ARM template reference page when the IaC is Bicep or raw ARM, or the Terraform `azurerm`/`azapi` provider page (or the HashiCorp page when Learn does not host it) when the IaC is Terraform. Use the `microsoftdocs` MCP server.
2. Cross-reference the per-service Well-Architected Framework service guide Security section already fetched. The Security section might name some of the properties that affect the resource's security posture in prose.
3. From those two sources, build the resource's network-security-relevant property set per the criteria in the previous section. Record the set in the scratch file.

**Done when:** every distinct resource type in the inventory has a recorded network-security-relevant property set, sourced from Microsoft Learn pages fetched in this review.

## How to evaluate the IaC

For each resource instance in the inventory, walk the recorded property set and check whether the IaC sets each property:

- Set to a literal value in the IaC (Bicep property, Terraform attribute, ARM JSON field): explicit. No finding.
- Set via a module input, parameter, variable, or referenced output whose value is visible in the provided path: explicit. Follow the reference and read the value; this is the same handling as everywhere else in the skill. If the value resolves to "use the default" (e.g., `null`, an empty object, or omission inside a wrapper), treat as unset.
- Set via a module input, parameter, variable, or referenced output whose value is not visible in the provided path: covered by the [Failure modes section in SKILL.md](../SKILL.md#failure-modes). Ask for the caller or the value; do not assume.
- Not set at all (the property is absent from the resource definition): unset. Emit an implicit-defaults finding.

The check is property-by-property. A resource that sets two of five in-scope properties produces three findings, not one rolled-up finding.

## Severity rules

- **High** when the property defines the workload's network perimeter or the resource's reachability. This includes network security parameters such as: `publicNetworkAccess`, `networkAcls.defaultAction`, `apiServerAccessProfile.authorizedIpRanges`, `privateCluster`, `allowForwardedTraffic`, `allowVirtualNetworkAccess`, `allowGatewayTransit`, and `useRemoteGateways`. It also includes: NSG association on a workload subnet, WAF mode, TLS minimum version, any sub-resource public-endpoint enablement, IP firewall rules, virtual-network firewall rules, `bypass`, `ipSecurityRestrictions`, NAT/outbound configuration, UDR next-hop. If Microsoft or Hasicorp were to flip the default on this property and that would change which packets reach or which packets leave the workload/resource, it is High.
- **Medium** for everything else in scope.

Critical is reserved for active misconfiguration (a value is set and is unsafe). If the current default is unsafe, the corresponding flow finding (north-south or east-west) fires at Critical or High under its own rules.

## Interaction with the flow steps

- This step runs once, against the full inventory, before the flow steps.
- The flow steps (north-south, east-west) read the IaC literally: if a property is unset, the flow steps do not assume the default. They emit no flow finding for the property; this step's finding covers the gap. The flow finding is reserved for explicitly-set unsafe values.
- This split means a single resource with an unset `publicNetworkAccess` produces one implicit-defaults finding (from this step). It does not also produce a north-south finding for "publicNetworkAccess is Enabled" because the IaC does not say that; the IaC says nothing. The remediation in the implicit-defaults finding is to set the property explicitly, which forces the architect to choose a value the next reviewer can audit.

## Report section

Findings from this step go into a top-level `## Implicit IaC defaults` section in the report, sibling to Findings and Network lines-of-sight, placed immediately before Findings. See [report-rules.md](./report-rules.md#implicit-iac-defaults) for the exact shape.
