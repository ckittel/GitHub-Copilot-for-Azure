# Inventory mechanics

How to enumerate the IaC once it parses. Drives every later step: grounding, flow analysis, and findings all key off the inventory rows.

## What to capture per resource

Enumerate every networked resource and traffic-relevant feature. For each, capture:

- resource type
- logical name
- file path
- line number
- planes exposed (data, control, or both)
- the network features and controls that matter

## Split endpoints per plane

Some Azure resources expose separate endpoints per plane governed by different settings; others bundle both planes onto one FQDN. Capture both rows when the service splits them. The per-service Microsoft Learn Private Link page is the source of truth, see [concepts.md](./concepts.md).

## Resource families to look for

Non-exhaustive checklist; find families that applies to the IaC in scope.

- **Edge:** Front Door, Application Gateway, Load Balancer (public), API Management (external), Public IPs, DDoS plans.
- **Perimeter:** Azure Firewall, NVA, NAT Gateway, WAF policies, IP groups, route tables / UDRs.
- **Network fabric:** virtual networks, subnets, NSGs, ASGs, virtual network peerings, service endpoints, private endpoints, private DNS zones and links, ExpressRoute gateways, VPN gateways.
- **Compute:** VMs/VMSS, AKS (CNI, network policy, private cluster, authorized IP ranges), App Service / Functions (vnet integration, access restrictions), Container Apps.
- **State stores:** Storage, Key Vault, SQL, Cosmos, Service Bus, Event Hubs, ACR.
