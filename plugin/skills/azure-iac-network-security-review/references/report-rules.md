# Report rules

The empty report skeleton lives at [`../assets/report-template.md`](../assets/report-template.md). Copy it as the starting point for every report, then apply the rules in this file to populate each section. Do not deviate from the skeleton's structure without a reason.

## Header

The header section in the skeleton is the only allowed header. Do not invent additional fields. Rules per field:

- **IaC source**: the path the user provided and the language.
- **Review mode**:
  - Full workload: write exactly `Workload (full review).` Do not justify the mode, do not list what alternatives were ruled out, do not name the skill's other classifications.
  - Components-only: write `Components-only.` followed by one sentence stating what the IaC actually is, in the user's own domain (e.g., "The IaC is a hub-and-connectivity deploy with no workload application resources." or "The IaC is a module catalog whose consumers are out of scope.") and the user's authorization to proceed in this mode. Do not name the skill's classification list.
- **Environment**: always `production`. Re-evaluating against any other environment happens in the workload-refinement loop and is recorded in Assumptions.
- **Reviewed at**: the UTC date the review was run.

## Assumptions

List only the assumptions that affect a finding, beyond the dependency claims. One bullet per assumption. If there are none, write `_None._`

## Dependency claims

One table row per `tr:<id>` confirmed by the user, with the platform control the user attested to. For unverified statements, set the Verified? column to `N` and reference the Open questions item that supplies the verification command.

## Inventory summary

A short bulleted list of what was discovered in the IaC. The Ingress paths and Egress paths bullets are mandatory; the resource-count bullet should enumerate virtual networks, subnets, peerings, public IPs, PaaS resources with public surface, private endpoints, NSGs, and route tables.

## Network lines-of-sight

This section lists every lateral, ingress, or egress path the IaC permits. It is not a list of findings; it is a list of questions for the architect. You cannot tell from IaC alone whether `snet-web` reaching `sql-orders` on 1433 is the intended architecture or an over-permissive NSG the architect did not notice. Ask the user.

Populate from the connectivity graph built during the east-west walk. Required when east-west topology was in scope; omit in components-only mode.

One row per path. Rows are written top-down per the row-order rules below, ties broken by source then destination. Do not surface the ordering rationale in the report.

Row order (first match wins):

1. Admin ports across subnets (22, 3389, 5985/86, 10250, 2379/80); any reach to control plane from a workload subnet; any reach to a PaaS data store likely to hold sensitive data from a subnet that does not host a known client; any cross-virtual-network flow that does not transit a hub firewall; any path allowed by a wide service-tag rule (`Internet`, `AzureCloud`, broad `Storage`/`Sql` tags on egress).
2. Any peered-virtual-network flow; any flow allowed by a hard-coded CIDR rule instead of an ASG; any flow to a PaaS data plane on its standard port from a subnet whose naming does not suggest it is a consumer.
3. Flows inside a single virtual network between obviously-paired subnets on the standard application port (e.g., `snet-web` to `snet-api` on 443; `snet-app` to `snet-db` on 1433 when `snet-app` is clearly the client).

This section does not assign Critical/High/Medium/Low severities. Those are reserved for the Findings section and are awarded only when:

1. The path violates a categorical network security rule.
2. Or the user confirmed during the workload-refinement loop that the path is unintended. Promote the inventory row to a finding then, with the user's statement quoted in the Issue text.

After the user resolves the inventory in the workload-refinement loop, set each row's `Intended?` column to `Y`, `N`, or `accepted-risk`, move N-rows to the Findings section, and leave the completed table in the report so the next reviewer sees what was sanctioned.

## Implicit IaC defaults

Every network-security-relevant property that is not set explicitly in the IaC is one entry here. The current Microsoft default is irrelevant to whether the entry is emitted; it only changes severity.

This section is sibling to Findings, not a subset of it. The flow-finding numbering (`NS-###`, `EW-###`) does not apply; use `IMP-###`. Reliance on defaults is a defect class of its own, and the report keeps the two visibly separate so the reader can see at a glance how much of the workload's posture is implicit.

If no implicit-defaults findings were emitted, leave the skeleton's `_No implicit defaults..._` line in place.

Per entry, use this exact shape:

```markdown
### IMP-001: <resourceType> `<resourceName>` does not set `<property>`

- **Severity**: High or Medium.
- **Resource**: <resourceType>, <resourceName>
- **Location**: `<file>:<startLine>-<endLine>` (the resource block; the property's absence has no line of its own)
- **Property**: the unset property's full path on the resource (e.g., `properties.publicNetworkAccess`, `properties.networkAcls.defaultAction`, `apiServerAccessProfile.authorizedIpRanges`).
- **Current Microsoft default**: state the current default as documented on the Bicep/ARM reference page or Terraform provider page, with the URL. If the default is documented to vary by API version, SKU, or region, say so.
- **Issue**: 2 to 3 sentences. State that the property is unset; name what the property controls (one phrase); state that defaults change and the IaC must show its intent.
- **Remediation**: name the property and require it be set explicitly. State a recommended value when a Microsoft Learn source clearly prescribes it; otherwise require the architect to choose. If a built-in policy also enforces the property, it may be mentioned as a *separate* defense-in-depth recommendation, not as a way to close this finding.
- **Tradeoffs**: Usually `None significant` (setting a property explicitly costs nothing). If the recommended value carries operational burden (e.g., setting `publicNetworkAccess: Disabled` requires a private endpoint to be in place), name it; this is the same shape as the Findings-section Tradeoffs field.
  Avoid non-tradeoffs such as: restating that the feature will now enforce the control; stating that the change only works if another property is also set. A genuine tradeoff answers "what does the reader give up now that this property is set?"
- **References**:
  - The Bicep template reference URL or Terraform provider URL, deep-linked to the property.
  - The per-service **Well-Architected Framework service guide Security section** where it discusses the property (when applicable).
  - The MCSB control ID (`NS-*`) the property maps to, when one fits.
```

ID prefix: `IMP-###`. Number sequentially across the whole section; do not group by resource type.

High severity first, then Medium. Within a severity, group by resource type, so the reader can see a single resource's full explicitness gap in one read.

**No `Depends on:` field.** Trust statements do not downgrade or suppress implicit-defaults findings.

## Findings

Group by flow, then by severity, in this order: Critical, then High, then Medium, then Low, then Info.

If no findings were emitted, leave the skeleton's `_No network-security findings._` line in place. Do not omit the section; absence of the Findings section is ambiguous with the review not having happened.

Per finding, use this exact shape:

```markdown
### NS-001: <short title>

- **Severity**: Critical, High, Medium, Low, or Info
- **Plane**: data, control, or both.
- **Direction**: `ingress`, `egress`, or `lateral`.
- **Reachable from**: Name the attacker position the missing or weak control fails to defend against. Be specific. Append the transport in parentheses when it sharpens the picture (e.g., `Internet (unauthenticated TCP)`, `Adjacent subnet: snet-web (TCP/1433)`). Acceptable values include:
  - `Internet (unauthenticated)`
  - `Internet (authenticated user)`
  - `On-prem`
  - `Peered virtual network: <name or 'any spoke via hub'>`
  - `Adjacent subnet: <name>`
  - `Compromised component in subnet <name>`
  - `Compromised managed identity in subnet <name>` (for control-plane findings where the attacker has tokens and can reach an in-scope control plane)
  - `Partner / B2B caller` (when an `allow` rule references a partner range)
  - `Any host covered by service tag <tag>`: use when an `allow` rule references a service tag whose IP range is wider than the workload needs. Name the tag and, in one phrase, what it actually covers. Examples: `Any host covered by AzureCloud` (every Azure customers' VM in every subscription and region); `Any host covered by service tag AzureCloud.EastUS` (every Azure customers' VM in East US); `Any host covered by service tag AzureFrontDoor.Backend` (every Front Door tenant, including an attacker's, unless the origin also enforces the `X-Azure-FDID` header); `Any host covered by service tag Storage on egress` (every storage account in Azure, not just the ones the workload owns).

  If more than one source applies, list each on its own line. The reader must read this knowing exactly whose packet the missing control would have stopped.
- **Resource**: <resourceType>, <resourceName>
- **Location**: `<file>:<startLine>-<endLine>`
- **Issue**: 2 to 4 sentences. What is wrong, what attack/abuse path it enables, why it matters. The first sentence must connect the `Reachable from` source to the affected resource (e.g., "An unauthenticated Internet caller can reach the Storage blob endpoint because..."). For control-plane findings, name the data-plane controls the attacker could disable once the control plane is reached.
- **Evidence**: a 3 to 6 line code excerpt or specific property values from the IaC.
- **Remediation**: the property name(s) to change and the value(s) to set. Include a code snippet in the same IaC language (Bicep or Terraform) when the change is more than a single property. **Pair the IaC change with Azure Policy enforcement** whenever a built-in policy can evaluate the recommended state: name the built-in policy (`deny`-effect preferred, `auditIfNotExists` acceptable when no `deny` variant exists), state a suggested assignment scope, and add the policy reference URL to References. The policy is a *defense-in-depth recommendation*, never a substitute for the IaC change: IaC and Policy are independent controls. Verify the exact policy display name via the `microsoftdocs` MCP server before naming it. When no built-in policy matches the recommendation, say so explicitly in the Remediation ("No built-in Azure Policy enforces this property.") so the next reviewer doesn't assume one was missed; do not draft custom policy JSON in this skill.
- **Tradeoffs**: One to three bullets covering what the reader gives up by applying the remediation: operational burden, cost, latency/performance, developer experience, compatibility, dependency on the platform team. Pull primarily from the Well-Architected Framework service guide's tradeoffs call-outs; reason through the impact when Microsoft Learn doesn't have this data. When the Remediation names an Azure Policy assignment, Tradeoffs must include that platform-wide policy assignment requires coordination with the platform team and may break existing exceptions in sibling workloads. `"None significant"` is an acceptable value when no tradeoff applies, but the field cannot be omitted.
  When cost is a tradeoff, name it qualitatively only ("increases recurring cost", "adds per-GB egress cost"); never include a monetary figure, currency amount, percentage of another SKU's price, or any other numeric magnitude.
  
  Avoid non-tradeoffs such as: restating that the control will now be in effect (that is the remediation working as designed, not a cost); noting other findings the reader must also address; listing residual risks the remediation does not claim to close; stating that the remediation only works if another property is also set or another finding is also fixed; or describing what currently-working things could break when the remediation is applied. A genuine tradeoff answers "what does the reader give up to gain this?" Risks are not tradeoffs.
- **References**: At minimum:
  - The MCSB control ID the finding maps to, with a deep link to `learn.microsoft.com/security/benchmark/azure/mcsb-v2-network-security`. Required whenever a Network Security family control fits. If none fits, re-check that the finding is in scope.
  - At least one prescriptive Microsoft Learn URL: the per-service **Well-Architected Framework service guide** Security section. The MCSB deep link above counts; a service-specific Well-Architected Framework service guide link is strongly preferred when one exists.
  - Optional supplementary URLs: the component's per-service networking reference doc, zero trust documentation, Azure security fundamentals, or a relevant built-in Azure Policy. Listed after the primary-source citation(s). Do not label them as primary or supplementary.
  - Never include an excluded source from [learn-grounding.md](./learn-grounding.md).

  Use deep links (`#section-anchor`) where available.
- **Depends on** (optional): trust statement IDs from [dependencies.md](./dependencies.md) that mitigate this finding. Append `?` to any unverified statement. If present, the Issue text must explicitly say what the user is trusting the platform to do.
```

ID prefixes: `NS-###` for north-south, `EW-###` for east-west. Number sequentially within each flow.

## Open questions for the user

Anything that blocked a confident finding: runtime parameters, missing modules, unaffirmed platform trust statements. Number them so the user can answer inline.

Include one entry per confirmed trust statement, with a verification command so the user can later confirm the platform actually does what they attested to. Example:

```markdown
6. **Verify `tr:hub-egress-firewall`**: confirm the spoke's effective routes send `0.0.0.0/0` to the hub firewall.
```

## Suppressed by workload context

Created and populated only after the workload-refinement loop. Findings the user has explicitly accepted, deferred, or invalidated based on functional/non-functional requirements they shared. Never delete a suppressed finding; move it here with:

- The original ID and one-line title.
- Original severity.
- Suppression reason (one or two sentences quoting the user's input).
- Compensating control or accepted risk, if any.

If the refinement step has not run yet, omit this section.

## Out of scope

Always include this section verbatim from the skeleton at [`../assets/report-template.md`](../assets/report-template.md), regardless of review mode and regardless of whether the workload-context refinement step ran. Do not paraphrase. Do not add or remove bullets. Do not omit the Azure Resource Manager subsection.

---

## Style rules for the findings document

- Report only what is broken, missing, weak, or unverified. No "strengths" section, no "correctly configured" entries, no positive framing. The Inventory summary and Network lines-of-sight are the coverage proof; the findings list is the work list.
- Do not soften. No "consider," "you may want to," "it might be worth." State the issue, the impact, and the required change.
- No narrative executive summaries.
- Cite file:line(s) for everything. A finding without a location is not helpful to the user.
- Cite at least one Microsoft Learn URL for everything. A finding without Learn grounding is not emitted by this skill.
- One concrete change per finding. If a single bad pattern produces ten findings, write one finding and list the ten locations.
- No generic remediations. "Harden the network," "follow least privilege," and "enable monitoring" are not remediations; name the property and the value.
- No findings invented from defaults. Read the IaC literally. If a property is absent and the Azure default is insecure, that *is* a finding, but say so explicitly ("property `publicNetworkAccess` not set; Azure default is `Enabled` per <learn URL>").
- Trust statements never erase a finding; they only downgrade severity and add a `Depends on` tag. The reader must always see the IaC gap and what is purportedly covering it.
- Every remediation must be paired with its tradeoffs. A recommendation without consequences is incomplete. "None significant" is allowed; an empty field is not.
- Address findings to the IaC, not the user. Do not editorialize on the architect's intent or skill.
- Line-of-sight is not a finding on its own. A data-plane east-west path that the IaC allows but that is not a categorical defect belongs in the [Network lines-of-sight](#network-lines-of-sight) section, not the Findings list. Promote a row to a finding only after the user confirms in the workload-refinement loop that the path was unintended, or when the path is itself a categorical defect. Control-plane line-of-sight rows are always findings; the bar there is "no legitimate need," not "user confirms unintended."
- Missing a second layer of defense is a finding only when that pair is in the Required defense-in-depth pairs. Do not invent defense-in-depth recommendations. For drift concerns, the remediation includes a `deny`-effect built-in Azure Policy assignment, not additional stacked Azure controls.
- Remediations must remove the insecure surface, not harden it.
