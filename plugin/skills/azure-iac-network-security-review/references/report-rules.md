# Report rules

The empty report skeleton lives at [`../assets/report-template.md`](../assets/report-template.md). Copy it as the starting point for every report, then apply these rules to populate each section. Do not deviate from its structure without a reason.

## Header

The skeleton's header is the only allowed header. Do not invent additional fields. Rules per field:

- **IaC source**: the path the user provided and the language.
- **Review mode**:
  - Full workload: write exactly `Workload (full review).` Do not justify the mode, list ruled out alternatives, or name the skill's classifications.
  - Components-only: write `Components-only.` followed by one sentence stating what the IaC actually is, in the user's own domain (e.g., "The IaC is a hub-and-connectivity deploy with no workload application resources." or "The IaC is a module catalog whose consumers are out of scope.") and the user's authorization to proceed. Do not name the skill's classifications.
- **Environment**: always `production`. Re-evaluation against any other environment happens in the workload-refinement loop and is recorded in Assumptions.
- **Reviewed at**: the UTC date the review was run.

## Assumptions

List only the assumptions that affect a finding, beyond the dependency claims. One bullet per assumption. If there are none, write `_None._`

## Dependency claims

One table row per `tr:<id>` the user confirmed, with the platform control they attested to. For unverified statements, set Verified? to `N` and reference the Open questions item that supplies the verification command.

## Inventory summary

A short bulleted list of what the IaC contains. The Ingress paths and Egress paths bullets are mandatory; the resource-count bullet should enumerate virtual networks, subnets, peerings, public IPs, PaaS resources with public surface, private endpoints, NSGs, and route tables.

## Network lines-of-sight

This section lists every lateral, ingress, or egress path the IaC permits. It is a list of questions for the architect, not findings. You cannot tell from IaC alone whether `snet-web` reaching `sql-orders` on 1433 is intended or an over-permissive NSG nobody noticed. Ask the user.

Populate from the connectivity graph built during the east-west walk. Required when east-west topology was in scope; omit in components-only mode.

One row per path, written top-down per the row-order rules below, ties broken by source then destination. Do not surface the ordering rationale in the report.

Row order (first match wins):

1. Admin ports across subnets (22, 3389, 5985/86, 10250, 2379/80); any reach to control plane from a workload subnet; any reach to a likely sensitive PaaS data store from a subnet that hosts no known client; any cross-virtual-network flow that doesn't transit a hub firewall; any path allowed by a wide service-tag rule (`Internet`, `AzureCloud`, broad `Storage`/`Sql` on egress).
2. Any peered-virtual-network flow; any flow allowed by a hard-coded CIDR instead of an ASG; any flow to a PaaS data plane on its standard port from a subnet whose naming doesn't suggest a consumer.
3. Flows inside a single virtual network between obviously-paired subnets on the standard application port (e.g., `snet-web` to `snet-api` on 443; `snet-app` to `snet-db` on 1433 when `snet-app` is clearly the client).

This section does not assign severities. Those are reserved for Findings, awarded only when:

1. The path violates a categorical network security rule, or
2. The user confirmed during the workload-refinement loop that the path is unintended. Promote the row to a finding then, quoting the user's statement in the Issue text.

After the user resolves the inventory, set each row's `Intended?` column to `Y`, `N`, or `accepted-risk`, move N-rows to Findings, and leave the completed table in the report so the next reviewer sees what was sanctioned.

## Implicit IaC defaults

Every network-security-relevant property not set explicitly in the IaC is one entry here. The current Microsoft default is irrelevant to whether the entry is emitted; it only changes severity.

This section is sibling to Findings, not a subset. Reliance on defaults is its own defect class, kept visibly separate so the reader sees at a glance how much of the posture is implicit.

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
- **Tradeoffs**: Usually `None significant`. If the recommended value carries operational burden (e.g., `publicNetworkAccess: Disabled` requires a private endpoint in place), name it. Same shape and non-tradeoff rules as the Findings-section Tradeoffs field.
- **References**:
  - The Bicep template reference URL or Terraform provider URL, deep-linked to the property.
  - The per-service **Well-Architected Framework service guide** Security section discussing the property (when applicable).
  - The MCSB control ID (`NS-*`) the property maps to, when one fits.
```

ID prefix: `IMP-###`. Number sequentially across the section; do not group by resource type.

High severity first, then Medium. Within a severity, group by resource type so the reader sees a single resource's full explicitness gap in one read.

**No `Depends on:` field.** Trust statements do not downgrade or suppress implicit-defaults findings.

## Findings

Group by flow, then by severity: Critical, High, Medium, Low, Info.

If no findings were emitted, leave the skeleton's `_No network security findings._` line in place. Do not omit the section; an absent Findings section is ambiguous with the review not having happened.

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
  - `Compromised managed identity in subnet <name>` (control-plane findings where the attacker has tokens and can reach an in-scope control plane)
  - `Partner / B2B caller` (when an `allow` rule references a partner range)
  - `Any host covered by service tag <tag>`: use when an `allow` rule references a service tag wider than the workload needs. Name the tag and, in one phrase, what it covers. Examples: `Any host covered by AzureCloud` (every Azure customer's VM in every subscription and region); `Any host covered by service tag AzureFrontDoor.Backend` (every Front Door tenant, including an attacker's, unless the origin enforces the `X-Azure-FDID` header); `Any host covered by service tag Storage on egress` (every storage account in Azure, not just the workload's).

  If more than one source applies, list each on its own line. The reader must finish this knowing exactly whose packet the missing control would have stopped.
- **Resource**: <resourceType>, <resourceName>
- **Location**: `<file>:<startLine>-<endLine>`
- **Issue**: 2 to 4 sentences. What is wrong, what attack/abuse path it enables, why it matters. The first sentence must connect the `Reachable from` source to the affected resource (e.g., "An unauthenticated Internet caller can reach the Storage blob endpoint because..."). For control-plane findings, name the data-plane controls the attacker could disable once the control plane is reached.
- **Evidence**: a 3 to 6 line code excerpt or specific property values from the IaC.
- **Remediation**: the property name(s) to change and the value(s) to set. Include a code snippet in the same IaC language (Bicep or Terraform) when the change is more than a single property. **Pair the IaC change with Azure Policy enforcement** whenever a built-in policy can evaluate the recommended state: name the policy (`deny`-effect preferred, `auditIfNotExists` when no `deny` variant exists), state a suggested assignment scope, and add the policy URL to References. The policy is a *defense-in-depth recommendation*, never a substitute for the IaC change; the two are independent controls. Verify the exact policy display name via the `microsoftdocs` MCP server first. When none matches, say so explicitly ("No built-in Azure Policy enforces this property.") so the next reviewer doesn't assume one was missed; do not draft custom policy JSON.
- **Tradeoffs**: One to three bullets covering what the reader gives up by applying the remediation: operational burden, cost, latency/performance, developer experience, compatibility, platform team dependency. Pull primarily from the Well-Architected Framework service guide's tradeoffs call-outs; reason through the impact when Microsoft Learn lacks it. When the Remediation names an Azure Policy assignment, Tradeoffs must note that platform-wide assignment requires platform team coordination and may break existing exceptions in sibling workloads. `"None significant"` is acceptable when no tradeoff applies; the field cannot be omitted.

  When cost is a tradeoff, name it qualitatively only ("increases recurring cost", "adds per-GB egress cost").
  
  Avoid non-tradeoffs such as: restating that the control will now be in effect (that is the remediation working as designed, not a cost); noting other findings the reader must also address; listing residual risks the remediation does not claim to close; stating that the remediation only works if another property is also set or another finding is also fixed; or describing what currently-working things could break when the remediation is applied. A genuine tradeoff answers "what does the reader give up to gain this?" Risks are not tradeoffs.
- **References**: At minimum:
  - The MCSB control ID the finding maps to, deep linked to `learn.microsoft.com/security/benchmark/azure/mcsb-v2-network-security`. Required whenever a Network Security family control fits. If none fits, recheck that the finding is in scope.
  - At least one prescriptive Microsoft Learn URL: the per-service **Well-Architected Framework service guide** Security section. The MCSB deep link above counts; a service-specific Well-Architected Framework service guide link is strongly preferred when one exists.
  - Optional supplementary URLs: the component's per-service networking reference doc, zero trust documentation, Azure security fundamentals, or a relevant built-in Azure Policy. Listed after the primary-source citation(s). Do not label them as primary or supplementary.
  - Never include an excluded source from [learn-grounding.md](./learn-grounding.md).

  Use deep links (`#section-anchor`) where available.
- **Depends on** (optional): trust statement IDs from [dependencies.md](./dependencies.md) that mitigate this finding. Append `?` to any unverified statement. If present, the Issue text must explicitly say what the user is trusting the platform to do.
```

ID prefixes: `NS-###` for north-south, `EW-###` for east-west. Number sequentially within each flow.

## Open questions for the user

Anything that blocked a confident finding: runtime parameters, missing modules, unaffirmed platform trust statements. Number them so the user can answer inline.

Include one entry per confirmed trust statement, with a verification command so the user can later confirm the platform does what they attested to. Example:

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

## This report didn't review

Always include this section verbatim from the skeleton at [`../assets/report-template.md`](../assets/report-template.md), regardless of review mode and whether the refinement step ran. Do not paraphrase, add, or remove bullets.

---

## Style rules for the findings document

- Report only what is broken, missing, weak, or unverified. No "strengths" section, "correctly configured" entries, or positive framing. The Inventory summary and Network lines-of-sight are the coverage proof; the findings list is the work list.
- Do not soften. No "consider," "you may want to," "it might be worth." State the issue, the impact, and the required change.
- No narrative executive summaries.
- Cite file:line(s) for everything. A finding without a location is not actionable.
- Cite at least one Microsoft Learn URL for everything. A finding without Learn grounding is not emitted.
- One concrete change per finding. If one bad pattern produces ten findings, write one finding and list the ten locations.
- No generic remediations. "Harden the network," "follow least privilege," and "enable monitoring" are not remediations; name the property and value.
- No findings invented from defaults. Read the IaC literally. If a property is absent and the Azure default is insecure, that *is* a finding, but say so explicitly ("property `publicNetworkAccess` not set; Azure default is `Enabled` per <learn URL>").
- Trust statements never erase a finding; they only downgrade severity and add a `Depends on` tag. The reader must always see the IaC gap and what purportedly covers it.
- Every remediation must be paired with its tradeoffs. "None significant" is allowed; an empty field is not.
- Address findings to the IaC, not the user. Do not editorialize on the architect's intent or skill.
- Line-of-sight is not a finding on its own. A data-plane east-west path the IaC allows but that is not a categorical defect belongs in [Network lines-of-sight](#network-lines-of-sight), not Findings. Promote a row only after the user confirms it was unintended, or when the path is itself a categorical defect. Control-plane rows are always findings; the bar there is "no legitimate need," not "user confirms unintended."
- Missing a second layer of defense is a finding only when that pair is in the Required defense-in-depth pairs. Do not invent defense-in-depth recommendations. For drift concerns, the remediation includes a `deny`-effect built-in Azure Policy assignment, not additional stacked Azure controls.
- Remediations must remove the insecure surface, not harden it.

## Self-contained and external-sourced

The report must be self-contained: assume the reader has no access to this skill's files. Never write file names (`SKILL.md`, `references/*.md`, `assets/...`) or step numbers into the report; References cite only external sources (Microsoft Learn URLs, Azure Policy built-in URLs). Carry rule rationale into the report in your own words.

Strip the locale from every Microsoft Learn URL in the report: remove the `/en-us` segment so the reader lands in their own locale (cite `https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-network-security#ns-2`, not the `/en-us` form). Applies only to report URLs; scratch-file URLs and URLs the agent fetches keep `/en-us`.
