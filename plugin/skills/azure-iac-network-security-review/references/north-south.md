# North-south review

Traffic between the workload and anything outside it: between internet and workload; between on-premises and the workload (over ExpressRoute or VPN); between an external customer or partner and the workload; between another tenant or sibling workload and this one.

The goal is to answer, for every path that crosses the workload edge boundary: what reaches it, what filters it, what observes it, and what the blast radius is if it is abused.

Every path must also be labeled as data plane or control plane. Control-plane exposure compounds risk: an attacker who reaches a resource's control surface can disable the data-plane controls the rest of this review depends on.

Before running step 2 below, you must have completed [SKILL.md](../SKILL.md) step 6 (Learn grounding) for every component family in the inventory. The tables in this file frame the procedure (what to look for, in what order, with what severity); the authoritative source for each check is the Microsoft Learn page fetched via the `microsoftdocs` MCP server. If a check here conflicts with current Learn guidance, Learn wins. See [learn-grounding.md](./learn-grounding.md) for the precedence rules.

## Step 1. Enumerate every entry and exit point

For each entry and exit point, capture which plane is reachable: `data`, `control`, or `both`. When a single resource exposes endpoints for both planes, record them as separate rows. The lists below frame *what kinds* of paths to look for; the actual entries come from the inventory in [SKILL.md step 2](../SKILL.md#2-inventory-the-iac), not from this file.

### Inbound (ingress): list every resource that can receive traffic from outside the workload

**Data plane.** Enumerate every resource the IaC exposes to a caller outside the workload boundary. Categories to look across:

- L7 entry points that take Internet traffic and route it inward (Front Door, App Gateway, APIM, and equivalents).
- L3/L4 entry points (public IPs, public load balancer frontends, anything that brings an external packet onto a workload NIC).
- PaaS endpoints with public-network access set to `Enabled`. Read the IaC literally; an unset property is the IaC explicitness review's domain ([SKILL.md step 7](../SKILL.md#7-verify-explicit-iac-coverage-of-network-security-properties)), not this step's.
- Gateway data paths (VPN, ExpressRoute) that carry on-prem traffic in. On-prem is external; the gateway does not vouch for what it carries.

**Control plane.** For every resource in the inventory, identify which of its endpoints carry management traffic and which of those are reachable from outside the workload. The split between data and control plane varies by service. Examples of what surfaces here: AKS API server, management agents on VMs, and any PaaS that exposes a separately-reachable control-plane API.

For each path, capture: file:line(s), the listener/endpoint, the protocol/port, the plane, what filters sit in front (WAF, NSG, firewall, IP restrictions), and what backend it forwards to.

### Outbound (egress): list every path leaving the workload

Enumerate every path through which the workload can initiate traffic outward. The principle: nothing leaves the workload boundary except through a path the IaC explicitly defines and that this review can name.

- Default outbound on compute (VMs, App Service, AKS, anything with an unconfigured egress). "No explicit path" is itself a finding.
- Forced tunneling: UDRs sending `0.0.0.0/0` to a firewall or NVA, plus any exceptions the IaC carves out.
- Service-endpoint / private-endpoint paths that, despite being "private," still let the workload reach Azure-wide tenants (storage accounts in any subscription, for example) without policy scoping.

## Step 2. For each ingress path, evaluate the control stack

Walk the path in order: first the edge, then the perimeter, then the subnet, then the resource. A finding is what is *missing*, not what is present. The Plane column is mandatory.

| Plane | Layer | Examples of what to check | Example red flags |
| :---- | :---- | :------------------------ | :---------------- |
| Data | Edge (Front Door / AppGW / APIM) | TLS version, cert source, WAF policy attached, WAF in `Prevention` not `Detection`, managed ruleset version current, custom rules, bot protection. **Paired with:** subnet NSG on the AppGW subnet (required pair, see [defense-in-depth.md](./defense-in-depth.md#required-pairs)). | No WAF; WAF in Detection in prod; TLS < 1.2; self-signed or expired cert; default rules disabled; WAF present without subnet NSG |
| Data | DDoS | Network DDoS Protection Plan attached to the virtual network holding public IPs; or service-native DDoS. **Paired with:** WAF on the L7 public endpoint (required pair, see [defense-in-depth.md](./defense-in-depth.md#required-pairs)). | Standalone public IPs with no DDoS plan in prod; DDoS plan without WAF on the public L7 entry |
| Data | L4 filtering | NSG on the subnet of the public-facing resource, restrictive source ranges where applicable | No NSG on the subnet; `Any`/`Internet` allowed to any port that is not the resource's documented public data port; any allowed Internet source on administrative protocols (SSH, RDP, WinRM), database wire protocols, or container runtime / orchestrator endpoints |
| Data | App-level filtering | App Service `ipSecurityRestrictions`, APIM IP filter policies, AppGW listener host/path rules. **Paired with:** WAF in front when the app is public (required pair, see [defense-in-depth.md](./defense-in-depth.md#required-pairs)); `ipSecurityRestrictions` denies early at the platform even if the WAF is bypassed via the App Service default hostname. | `Allow all` with no overlay, wildcard hosts; WAF in front without `ipSecurityRestrictions` locking the origin |
| Data | Resource public surface | `publicNetworkAccess`, firewall rules, network ACLs on the data sub-resource (blob, file, secret, listener). **Paired with:** when a private endpoint exists, `publicNetworkAccess: Disabled` is required (see [defense-in-depth.md](./defense-in-depth.md#required-pairs)); and every private endpoint requires a private DNS zone link to each resolving virtual network. | `publicNetworkAccess: Enabled` on PaaS without an overlying private endpoint or strict firewall; private endpoint present with `publicNetworkAccess` still `Enabled`; private endpoint without private DNS zone link |
| Control | AKS API server | `privateCluster: true` or non-empty `apiServerAccessProfile.authorizedIpRanges`; private endpoint for the API server when private | API server reachable from `0.0.0.0/0`; no authorized IP ranges |
| Control | PaaS service-specific control-plane sub-resources | For every PaaS family in scope, look up the service's Private Link page on Microsoft Learn (per [SKILL.md step 6](../SKILL.md#6-ground-each-component-family-in-microsoft-learn)) and confirm each control-plane API the service exposes is either private-endpointed or has its public endpoint disabled. | Data APIs locked down via private endpoint while a separately-reachable control-plane is left public |
| Control | Bastion / JIT | Bastion present in a hub; no public RDP/SSH on workload NICs; Bastion SKU supports auditing | Public 22/3389 anywhere; missing Bastion when VMs are in scope |
| Both | Observability | Every filtering control on this path must be paired with a diagnostic setting that ships its rule hits to a Log Analytics workspace, and that log stream must feed a detector that converts unusual traffic into an alert. A control whose decisions are not logged cannot be audited after an incident. A log stream nothing reads is a forensic artifact not a security control. | Filtering control in the IaC with no diagnostic setting; flow logs not enabled; logs collected but no `tr:network-detection` and no in-IaC alert rule pointing at them |

### WAF rule fitness

The edge row above covers WAF *presence and mode*. Presence and mode are necessary but not sufficient. For each WAF policy:

- Is the current major managed ruleset that Microsoft Learn names as the recommended default for new deployments attached? An out-of-date ruleset is its own finding even when one is attached.
- Do the rules fit the app's surface and language?
- For each custom rule, can you tie it back to a property of this workload? Custom rules that cannot be tied back to the IaC at hand are noise at best and gaps at worst.
- Every exclusion narrows the WAF for a specific reason. Review each one against the workload: is there an IaC-visible caller or path that requires it? Unexplained exclusions are findings.

## Step 3. For each egress path, evaluate exfiltration controls

The goal for every egress path enumerated in step 1 is the same: the workload should only be able to reach destinations it has a documented reason to reach, and that reach should be enforced at a chokepoint the IaC names.

- **Egress chokepoint is explicit.** "No UDR, so default Azure routing applies" equals uncontrolled egress; the chokepoint must be a UDR to a firewall, NVA, or NAT or a service-native equivalent the IaC declares.
- **Allowlists are scoped to the workload's actual dependencies.** Whatever egress filter the IaC declares, its allowed destinations should map back to consumers visible in the same IaC. Wildcards, broad FQDN globs, and service-tag allows wider than the workload's real callees are findings.
- **PaaS components participate in the same chokepoint.** PaaS resources that issue outbound traffic must be virtual-network integrated so their egress is subject to the workload's filter; otherwise their egress leaves through the platform's default path and bypasses the review.
- **Private resolution actually resolves privately.** Every private endpoint requires private DNS zone links to each virtual network that resolves it. A private endpoint with no zone link silently falls back to public DNS and the public endpoint if still enabled.
- **Allowed traffic gets inspected, not just routed.** The egress chokepoint should inspect the traffic it allows. When the IaC declares Azure Firewall Standard with no IDPS, or routes egress to an NVA whose inspection posture is not declared, emit a finding unless the user confirms `tr:platform-idps`. Cite MCSB `NS-4` (Deploy intrusion detection/intrusion prevention systems).

## Step 4. Validate the workload's external-edge controls

The edge to non-Internet outside callers (on-prem, partners, sibling workloads) is the same kind of boundary as the Internet edge and must be filtered the same way. "It's not the Internet" is not a trust statement.

- **Gateway-bound traffic is filtered as if it were external.** ExpressRoute and VPN gateways carry on-prem traffic in and out. Confirm that advertised prefixes are scoped to what the workload actually needs to receive and that a firewall sits between the gateway subnet and the rest of the spoke.
- **Administrative access uses a managed broker.** Direct public access to administrative protocols on workload NICs is a finding regardless of source filtering; the workload must use Bastion or an equivalent the user declares.
- **Cross-tenant allows are scoped to the partner the workload actually integrates with.** Allow rules that reference partner IP ranges or wide service tags (`AzureCloud`, `Internet`) must trace back to a named integration in the workload; otherwise they are too broad.

## Step 5. Write findings

For each gap, emit a row per the [report rules](./report-rules.md). Severity guidance:

- **Critical**
  - management ports open to Internet
  - PaaS data with secrets exposed publicly (Key Vault, Storage with anonymous blob, SQL with `0.0.0.0` rule)
  - no WAF on public web app in prod
  - no DDoS plan on prod public IPs serving customer traffic
  - AKS API server reachable from `0.0.0.0/0` in prod
- **High**
  - WAF in Detection mode in prod
  - WAF rules not aligned with the workload's actual surface
  - Legacy TLS or cyphers are allowed
  - uncontrolled egress in prod
  - private endpoint without private DNS zone link
  - AKS API server publicly reachable with authorized IP ranges that are too broad
  - for services that expose a separately-reachable control-plane, the data plane locked down via private endpoint but the control-plane left public
  - SKUs that lack required network security features
- **Medium**
  - missing diagnostic/flow logs
  - overly broad service tag allows (`Internet`, `AzureCloud`)
  - on-prem advertised prefixes too broad
- **Low / Info**
  - naming/tagging inconsistencies that hinder review

Every north-south finding must name the attacker position (threat source) explicitly in the `Reachable from` field per the [report rules](./report-rules.md). For this flow the source is almost always one of:

- `Internet (unauthenticated)`: the default for any public IP, public LB frontend, PaaS endpoint with no private endpoint in front, AppGW/Front Door listener, AKS API server without authorized IP ranges.
- `Internet (authenticated user with stolen credentials)`: use when the resource requires auth at the app layer but the network surface is open. The finding is that the network filter is missing; auth alone is not a network control.
- `On-prem (via ExpressRoute / VPN)`: use when the path crosses the gateway and BGP advertises overly broad prefixes, or when on-prem ranges have direct access to workload subnets without a firewall.
- `Partner tenant / B2B caller`: use when an `allow` rule references partner IP ranges.
- `Any host covered by service tag <tag>`: use when a rule references a service tag whose IP range is wider than the workload needs. Name the tag and, in one phrase, what it actually covers. Examples: `AzureCloud` is every Azure customer's VM in every subscription and region; `AzureFrontDoor.Backend` is every Front Door tenant (including an attacker's) unless the origin also enforces the `X-Azure-FDID` header; `Internet` is literally every host on the public Internet; `Storage` on egress is every storage account in Azure, not just the ones the workload owns.

If the IaC blocks one source but leaves another open, file the finding against the source that is still open and say so.

Each finding must include: the affected plane (`Plane: data`, `control`, or `both`), the threat source (`Reachable from:`), a concrete remediation that names the resource property and value to change, and the citations required by [learn-grounding.md](./learn-grounding.md): the MCSB control ID (NS-*) when one applies, plus at least one prescriptive Microsoft Learn URL.

## Apply to every candidate finding

Apply the [per-finding rules](./flow-analysis.md#per-finding-rules) to output from this flow analysis.
