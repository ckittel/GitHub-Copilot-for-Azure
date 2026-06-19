# Workload coherence check

The skill is designed to review full or a clearly interconnected part of a workload represented as IaC.

## Classification heuristics

Apply these heuristics to the inventory. None is conclusive on its own; weigh them together:

- **Topological connectivity**: do the virtual networks peer (directly or via a hub)? Are private endpoints' subnets reachable from the virtual networks that host their consumers?
- **Naming and tagging cohesion**: shared prefix, shared `workload`/`app`/`env` tags, or a consistent resource-group naming pattern?
- **Resource-group structure**: one to a handful of RGs scoped to this workload, vs. dozens spanning unrelated purposes.
- **Private endpoint and client pairing**: every private endpoint should have a plausible client inside the same inventory. Private endpoints with no consumer in scope suggest shared infrastructure or a misaimed review.
- **Edge surface check**: zero or one entry points (Front Door / App Gateway / APIM) usually means one workload. Many independent edges with no shared backend usually means multiple workloads or a module library.
- **Repo structure clues**: a single `main.bicep` or single root Terraform module is more likely a workload; a `modules/` library with `examples/` directories is more likely a module catalog.

## Classifications

Classify the inventory into exactly one:

- **Workload**: proceed with the full review.
- **Multiple workloads**: the inventory contains more than one distinct workload (e.g., a monorepo with several application landing zones). Stop and ask the user interactively which one to review.
- **Pure component library or module catalog**: reusable IaC modules with no instantiation. Hard stop. This skill reviews intended posture, not module APIs; a library's security properties depend entirely on how it is consumed. Tell the user the skill cannot review the library directly and ask them to point at an instantiation. Do not offer components-only mode for this classification.
- **Shared platform or connectivity deploy**: a hub, a connectivity subscription, a shared services subscription. Stop and tell the user this skill is workload-focused. Offer components-only mode as a fallback.
- **Grab bag or unclear**: does not fit any of the above. Stop, do not proceed by guessing.

## When the classification is not Workload

For any classification other than Workload:

1. Pause and present the classification with the evidence that drove it.
2. Ask interactively with the user's choices as options: scope down to a subfolder, pick one workload from many, run components-only mode, or abort.
3. Wait for the user's answer. Do not pick a mode for them.

## Components-only mode

If the user chooses components-only mode:

- Skip step 4 (no trust statements without a workload to anchor them to).
- Skip the east-west topology and reachability analysis. These need a workload shape to make sense; without one, there is no "intended architecture" to compare paths against.
- Still run east-west per-resource hardening checks: NSG admin-port rules from `*`/wide service tags, AKS NetworkPolicy presence, private endpoint + private DNS zone pair, `privateEndpointNetworkPolicies` semantics, subnet-purpose NSG expectations from [subnet-purposes.md](./subnet-purposes.md), and every entry in the [defense-in-depth required-pairs table](./defense-in-depth.md#required-pairs). These are security issues regardless of workload context.
- Run the north-south flow only for resources that have direct internet exposure.
- Run per-resource Learn-grounded hardening checks for every component family in the inventory.
- Flag the report header with `Review mode: components-only; no workload-level analysis performed.` and state which classification above drove it.
- Suppress the "Network lines-of-sight" section. Add an explicit note in the report that east-west topology and blast-radius analysis were not performed and why.
