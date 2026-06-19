# Network security principles

A consolidated list of the principles the skill is based on.

## Core posture

### Zero trust: no network position is trusted by default

No subnet, virtual network, peer, or platform-supplied path is assumed safe because of where it sits. Every reachable path is judged on whether it is needed and justified, not on its location in the topology.

### Assume breach

Network controls exist to contain the blast radius after an identity or application layer is already compromised. They are not the first line of defense; they are the layer that limits damage.

### Identity is the primary perimeter; network is the augmenting perimeter

Network controls augment identity; they never replace it. A workload whose network is locked down but whose identity layer is permissive is not secure; a workload whose identity layer is strong but whose network is wide open has given up its containment story.

## Resource-level principles

### A resource should only have *ingress* from the sources it needs

A resource should never be reachable from a network position it has no documented reason to receive traffic from. Reachability that the workload does not require is attack surface, regardless of whether any application-layer control would accept the request.

### A resource should only have *egress* to the destinations it needs

A resource should never be able to initiate traffic to a destination that is not a documented dependency of either the code or the platform it runs on. Uncontrolled egress is an exfiltration path.

### A resource should never expose more network surface than its role requires

Each listener, port, protocol, and FQDN the resource exposes is a separate attack surface, independent of who is allowed to reach it. A listener the resource does not need to fulfill its function should not exist in the first place; absence is stronger than any rule that would have rejected hostile traffic against it.

### Reachability and authorization are independent controls

Network reachability of a control-plane endpoint is its own concern even when the identity layer would refuse the call. Credential theft and network reach are separable risks: the attacker who has the credential can use it if and only if they can reach the surface.

### Private network paths must actually be private end to end

A "private" path that still has a parallel public path is not private; it is an additional way in. A PaaS resource fronted by a private endpoint while its public endpoint remains enabled is reachable two ways, and the more permissive way is the one an attacker will use.

### Administrative access uses a managed broker

Direct public reachability of administrative protocols (SSH, RDP, WinRM) on workload components is too big of a risk due to zero-day exploits of their protocols. The workload must reach those protocols via a managed broker such as Azure Bastion.

### Remove the insecure surface; do not harden it

The security control is the absence of the insecure listener, port, or protocol; not a mitigation layered on top of it.

### Traffic in transit must be encrypted and mutually authenticated where the protocol allows

A network path that carries application data without transport encryption is a wiretap path the moment it crosses any segment the workload does not own. Listeners only accept TLS, clients only initiate connections that negotiate the same, and minimum TLS version and cipher policy are pinned explicitly.

## Topology and segmentation principles

### Segment, filter, transform

Network security has three primitives, in this order:

1. **Segment**: create isolation boundaries (virtual networks, subnets, NSGs, ASGs, peerings, Kubernetes NetworkPolicy).
2. **Filter**: on every boundary, allow only what is expected, allowed, and safe.
3. **Transform & inspect**: mutate packets at the boundary where it adds defense (TLS termination + re-establishment, header stripping, payload inspection at the WAF).

### Filtering boundaries deny by default; rules add allowed paths

A filtering boundary whose default action is *allow* is not a security control; it is a logging point. Every NSG, firewall policy, subnet boundary, and broker boundary starts from "deny all" and grows by explicit allow rules for the traffic the workload is documented to need.

### Allowed traffic is still untrusted; inspect it

A filtering decision of "allow" is a routing decision, not a safety guarantee. For traffic the workload is required to accept, the allow rule only judged the envelope (source, destination, port, protocol), not the payload, and the content arriving to the listener is still assumed to be attacker-controlled. Where the traffic is high-value or crosses an Internet or partner boundary, an inspection layer (like an IDPS or WAF payload inspection) must look inside what was allowed.

### No single control should individually responsible (defense in depth)

A single control is a single point of security failure. If it is misconfigured, accidentally disabled, drifted, or bypassed, the door is wide open and nothing else notices. Every meaningful security control needs either a second control that covers the same failure mode at a different layer, or a mitigation that prevents the control itself from being disabled.

### Filtering controls must match the role of what they protect

A filtering control's rules are right or wrong only relative to what the protected segment is for. Every segment carries its purpose, and every control on its boundary is judged against that purpose.

### Workloads have many exits; each one is the same kind of boundary

The Internet edge, the ExpressRoute / VPN edge, partner edges, and edges to sibling workloads in shared hubs are all the same kind of boundary: traffic between the workload and something it does not own. None of them get a discount for not being "the Internet."

### Egress has one named chokepoint; everything flows through it

Egress traffic should leave the workload through a single explicit chokepoint.

### DNS resolution is a filterable perimeter

Name resolution is the first step of almost every outbound connection, and an attacker who controls DNS controls where the workload attempts to sends its traffic. The workload should resolve names through a controlled resolver so that resolution can be filtered, logged, and (when needed) blocked.

### Volumetric defenses only work at the edge

Layer 3 and 4 flood defenses, anti-spoofing, and large-scale rate-limiting shouldn't be applied inside the workload. These defenses must live at the platform's Internet edge, in front of every public IP the workload exposes. A workload that exposes a public IP without a volumetric defense in front of it has accepted that anyone with a botnet can take it offline.

## Observability and operability principles

### Network traffic should be observable

Every filtering control's allow and deny decisions must be emitted to a durable log sink the workload's responders can query. A control whose decisions are not logged cannot be audited after an incident, and a control whose decisions cannot be audited cannot be trusted to be doing what its rules say.

### Logging is not detection; something must watch the logs

A log stream that no system or human reads is not a security control; it is a forensic artifact for use after a breach. Every filtering control's log stream should feed a detector that converts "unusual traffic" into a notification.

### Network traffic should be directable

The workload's filtering controls must be able to change in response to an operational signal (a bad source, a compromised partner, a regulatory cutover) without redeploying the workload. This applies in both directions: ingress rules must be able to cut off a hostile or compromised source, and egress rules must be able to cut off a compromised destination the workload would otherwise keep reaching out to.

## Principles about network security controls in IaC

### The IaC must show its network security intent; defaults change

A network security property that is not set explicitly in the IaC is itself a security problem, regardless of whether the current Microsoft default is safe. Defaults change. "Relying on the default" is never a security control.

### IaC and Azure Policy are independent controls

A `deny`-effect Azure Policy that enforces a property does not make the unset property in IaC acceptable, and an explicit IaC value does not waive the policy. Each catches the other's drift: the policy catches IaC drift, the IaC catches policy scope changes.
