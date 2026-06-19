# Resolving the network lines-of-sight inventory

The Network lines-of-sight inventory is the set of lateral, ingress, and egress paths the IaC permits but that cannot be judged from IaC alone. This step resolves each path with the architect, turning unknowns into either confirmed findings or sanctioned paths. Run it only for a workload review; skip in components-only mode (no inventory was built).

## Walk the inventory with the user

Walk the inventory top-down, in row order. Present each row interactively with `Intended` / `Unintended` / `Accepted risk` options and quote the answer verbatim in the row.

- `Unintended`: promote to a Findings entry, score severity per the east-west rules in [east-west.md](./east-west.md), quote the user in the Issue text.
- `Accepted risk`: leave the row tagged `accepted-risk` with the reason; don't move to Findings or Suppressed.
- `Intended`: mark `Y` and stop; the completed inventory stays in the report.
- Re-rank only if the answer reveals a wrong tier.

Don't invite the broader workload context conversation until every row is resolved or explicitly deferred.
