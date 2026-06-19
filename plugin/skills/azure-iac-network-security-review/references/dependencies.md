# Dependencies

This file handles the things you can't see in the IaC because they live in a shared dependency, such as those defined in an Azure platform landing zone, not the application landing zone you're reviewing. Examples:

- The spoke deploys into a virtual network that already has a UDR forcing `0.0.0.0/0` through a hub Azure Firewall.
- Private DNS zones are centralized in the connectivity subscription; the spoke's private endpoints rely on a virtual network link the platform owns.
- A subscription-scope DDoS Network Protection plan is applied via Azure Policy.
- A deny-by-default Azure Policy assignment forces `publicNetworkAccess: Disabled` on PaaS at deploy time, regardless of what the IaC requests.
- Microsoft Defender for Cloud is enabled at MG scope with auto-provisioning of virtual network flow logs.

The skill cannot verify these from the IaC alone. The right behavior is to detect what is obviously absent from the IaC, ask the user once whether the platform supplies it, record the answer as a trust statement, and tag every affected finding so the user knows what was taken on faith.

Trust statements are the substitute for reading the dependency's IaC or live environment. The skill does not chase down hub or platform landing-zone repositories; the user's affirmation is what the skill operates on. If the user is wrong about what the dependency supplies, the trust statement is wrong and the finding's severity is wrong with it.

## When to run this step

After the inventory (SKILL.md step 2). Before Learn grounding. You need the inventory to know what to ask about; the checklist below is conditional on what is missing.

## Conditional prompts

For each row below, only ask the user if both conditions are true:

1. The component/control is absent from the IaC inventory.
2. It is the kind of thing a platform landing zone typically provides.

If something is present in the IaC, do not ask about it. If something is absent and is not a typical platform landing zone capability (e.g., application-specific Front Door rules), do not ask; treat it as a normal finding.

| If absent from IaC | Ask the user | If "yes", trust statement tag |
| :----------------- | :----------- | :---------------------------- |
| Azure Firewall / NVA, and no UDR `0.0.0.0/0` next-hop | "Does the target virtual network have a platform-applied UDR routing egress through a hub firewall?" | `tr:hub-egress-firewall` |
| Egress chokepoint with no declared payload inspection (Azure Firewall with no IDPS, NVA without inspection capability declared in the IaC) | "Does the platform-supplied egress chokepoint perform payload inspection on traffic leaving the workload?" | `tr:platform-idps` |
| Virtual network `dhcpOptions` is set to Azure DNS or is set to IPs not in the inventory | "Do the workload's virtual networks resolve DNS through a platform-controlled resolver that filters and logs outbound name resolution?" | `tr:platform-dns` |
| Private DNS zones for the private endpoints you found | "Are private DNS zones centralized in a connectivity/hub subscription with virtual network links to this spoke?" | `tr:central-private-dns` |
| Virtual network peering to a hub | "Is the spoke's virtual network peering to a platform hub managed outside this IaC?" | `tr:platform-peering` |
| Any peering whose `remoteVirtualNetwork.id` is not defined in the provided IaC | "`<peering name>` at `<file:line(s)>` peers to `<remote vnet id>`, which is not in scope. Who owns that virtual network, and what does the workload need to send to or receive from it?" | `tr:peering-<short-name>` (one per remote; the short name names the remote, e.g., `tr:peering-shared-services`, `tr:peering-partner-billing`). The trust statement text must record: owning team, remote's purpose for this workload (what the workload acts as a client to or server for), and the controls the owning team applies on their side. |
| Any UDR with a `nextHopType: VirtualAppliance` whose `nextHopIpAddress` is not a NIC in the inventory, or `nextHopType: VirtualNetworkGateway` when no gateway is in the inventory | "`<route name>` at `<file:line(s)>` sends `<address prefix>` to `<next-hop>`, which is not in scope. Who owns the appliance/gateway, and what does the workload need to send through it?" | `tr:udr-<short-name>` (one per next-hop, e.g., `tr:udr-hub-firewall`, `tr:udr-platform-nva`). Same recording requirements as `tr:peering-*`. |
| DDoS Network Protection plan | "Is a DDoS Network Protection plan applied to virtual networks via Azure Policy?" | `tr:platform-ddos` |
| NSGs on workload subnets | "Are deny-by-default baseline NSGs applied to spoke subnets via Azure Policy or by Azure Virtual Network Manager?" | `tr:policy-baseline-nsg` |
| ExpressRoute / VPN gateway | "Is on-prem connectivity terminated in a platform hub and reached via the peering above?" | `tr:platform-er-vpn` |
| Diagnostic settings on networking resources, Log Analytics workspace | "Are diagnostic settings deployed via Azure Policy?" | `tr:policy-diagnostics` |
| Detector that reads the network log streams | "Once the workload's network logs land in their log sink, is something reading them and producing alerts? Name the detector and its owner." | `tr:network-detection` |
| Azure Policy assignments restricting network configuration | "Are there Azure Policy denies enforcing network baselines (e.g., `Deny public IP creation`, `Deny PaaS without private endpoint`)?" | `tr:policy-network-deny` |
| Microsoft Defender for Cloud / Defender for Servers | "Is Defender for Cloud enabled at subscription scope, with the network-relevant plans (Defender for Servers, for Storage, for Key Vault) on?" | `tr:defender-enabled` |
| Bastion in the inventory, and any VM has a public IP-eligible NIC | "Is Azure Bastion provided in a platform hub for management access to this spoke?" | `tr:platform-bastion` |
| AKS in the inventory with `networkPolicy` engine enabled, and no `kind: NetworkPolicy` manifests in the provided path | "K8s `NetworkPolicy` resources are not in the IaC. Where do the workload's policy manifests live (Helm chart, Kustomize overlay, GitOps repo), and do they include a default-deny baseline per workload namespace?" | `tr:k8s-network-policies` |

Only the rows whose "absent from IaC" condition matches need a question.

Each individual instance of a finding is its own discrete question with a Yes / No / I don't know option set. Submit all of the step's questions together in a single invocation of the interaction. Do not present questions through prose do not collapse multiple rows into one combined question.

## How to use the answers

For each trust statement the user confirms:

- Add it to the "Dependency claims" section in the report header (see [report-rules.md](./report-rules.md)).
- When a finding would have been emitted but is mitigated by a trust statement, downgrade severity or suppress as appropriate and tag the finding with the trust statement ID (e.g., `Depends on: tr:hub-egress-firewall`). The finding still appears; the reader sees both the IaC gap and what's covering it.
- For each trust statement, add an entry to "Open questions" noting that the user should confirm with the platform owner that the control is actually in place once the environment is deployed.

If the user answers "no" or "I don't know":

- Treat the control as absent. Emit the finding at full severity. Do not tag.
- For "I don't know", also list it in Open Questions with the note "trust statement claimed unknown; confirm with platform owner before relying on it."

## What this is not

- Not a license to assume good things about the environment. Never volunteer a trust statement; the user must affirm each one.
- Not a way to score IaC favorably for things it doesn't do. The finding is always emitted; the trust statement only changes severity and adds a tag.
