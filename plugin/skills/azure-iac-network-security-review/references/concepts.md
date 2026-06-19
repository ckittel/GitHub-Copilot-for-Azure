# Concepts and rationale

This file conatins some elaboration of some key concepts used throughout the skill in case they need to be referenced during any dialog with the user.

## North-south vs east-west (direction)

North-south is the traffic between the workload and anything outside it. The "outside" set is heterogeneous: the public Internet, on-prem callers reaching the workload over ExpressRoute or VPN, external customers, partner tenants, and sibling workloads that share a hub but are not part of this deployment. The controls that apply at this edge are different in kind from internal controls: WAF, DDoS plans, public IP allocation, edge firewalls, FQDN allowlists at the egress point, gateway paths.

East-west is the traffic among the workload's own resources: virtual-network-to-virtual-network within the workload (peerings, hub-spoke), subnet-to-subnet, service-to-service via PaaS, pod-to-pod, and any lateral path an attacker with a foothold already inside the workload could use. The controls here are NSGs, ASGs, AKS NetworkPolicy, PaaS firewalls, private endpoints, private DNS, UDRs.

The distinction is topological, not a trust claim. The skill operates with zero-trust: no network position is trusted by default, including positions inside the workload. The N/S vs E/W split exists because the source population and the controls available are different, not because anything is "inside the perimeter" and therefore safe. East-west analysis does not assume any subnet is more trusted than any other; every lateral path is judged on whether it is *needed*, not on where it sits.

## Data plane vs control plane (plane)

Data-plane traffic is the bytes the workload exists to send or receive:

- HTTPS from a browser through Front Door or Application Gateway to a backend.
- SQL on 1433 from app tier to database.
- Blob reads and writes against a Storage account.
- Pod-to-pod traffic inside an AKS cluster.
- AMQP to Service Bus, Event Hubs ingest, Cosmos DB queries.

Control-plane traffic is the management surface that configures or operates the resources themselves. The FQDN and shape of this API surface is service-specific.

Some services bundle both planes onto a single FQDN, some split them, some have multiple control-plane sub-resources. Always look up the per-service Private Link page on Microsoft Learn for every PaaS family in scope. Do not assume.

The plane matters because a control-plane compromise lets the attacker turn off the data-plane controls. An attacker who can reach (and authenticate to) the per-service control plane or ARM itself can modify NSGs, drop firewall rules, disable private endpoints, and rotate routes. Any control the data plane relies on is conditionally compromised once the management surface is reachable.

The reachability-vs-authorization split exists because the two controls are independent: even if RBAC were perfect, leaving a control plane endpoint publicly reachable is still a finding, because that surface is a zero-day exploitable surface.

## ARM endpoint

Azure Resource Manager (`management.azure.com`) is intentionally not itemized by this skill.

- ARM is a global multi-tenant service. Its network surface is the public Internet by default and the only network-layer control for it (Azure Resource Manager Private Link) is not typically able to be implemented by a single workload.
- The [Out of scope section](./report-rules.md#out-of-scope) of every report restates this for the reader so the absence of ARM findings is not mistaken for a gap in the review.

## Trust statements

A trust statement is a named, user-sourced claim that a control the workload IaC does not contain is being provided by another layer (a platform landing zone, a centralized dependency, or a remote endpoint the user vouches for). The skill never assumes an external control exists.

## Remove the insecure surface; do not harden it

The security control is the absence of the insecure listener, port, or protocol, not a mitigation layered on top of it.

Examples:

- HTTP -> HTTPS redirect vs. rejecting HTTP.
- TLS 1.0/1.1 enabled with HSTS vs. minimum TLS 1.2+.
- FTP with TLS allowed vs. FTP disabled.

Static analysis tools and sometimes Microsoft Learn pages recommend a compatibility shim; the report's remediation must be removal.
