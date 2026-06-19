# Flow analysis rules

Per-finding rules shared by both flows (north-south and east-west). [north-south.md](./north-south.md) and [east-west.md](./east-west.md) invoke this file under their "Apply to every candidate finding" heading, applying each rule as a flow drafts a candidate finding.

## Learn wins over the static tables

If the Microsoft Learn data fetched during grounding conflicts with the static procedure tables or static text in this skill, Learn wins: emit the finding and cite the URL.

## Trust statement rescoring

Apply the trust statement rescoring rules in [dependencies.md](./dependencies.md). Skip in components-only mode; no trust statements exist there.

## Scope boundary

Never produce findings about IAM/RBAC, Managed Identities, Key Vault secret hygiene, encryption-at-rest, application authentication, cost, SKU sizing, or general reliability. Those are "out of scope for this review" if the user raises them.

For control-plane endpoints, the boundary is network reachability vs authorization: reachability is in scope, authorization is not. "AKS API server reachable from the Internet" is a finding; "too many people have `Contributor`" is not.
