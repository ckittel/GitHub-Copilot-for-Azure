---
name: azure-iac-network-security-review
description: "Audit the network security of Azure Bicep or Terraform infrastructure-as-code (IaC), grounded in Microsoft Learn. WHEN: \"review network security of my Bicep/Terraform\", \"audit IaC network exposure\", \"check NSGs and private endpoints in my IaC\". DO NOT USE FOR: non-IaC targets; IAM/RBAC, secrets, app auth, cost, SKU sizing, or reliability reviews; generic non-network security reviews."
license: MIT
disable-model-invocation: false
compatibility: Network access required to fetch Microsoft Learn content, access to static analysis tool for IaC files
argument-hint: path to Bicep or Terraform file or folder
metadata:
  author: Microsoft
  version: "0.0.0-placeholder"
---

# Azure IaC network security review

Audit the network security posture of Azure resources defined in Bicep or Terraform. Review along two axes:

- Direction
  - North-south: traffic between the workload and anything outside it (internet, on-prem, external dependencies, sibling workloads).
  - East-west: lateral traffic among the workload's own resources (vnet-to-vnet, subnet-to-subnet, service-to-service, pod-to-pod).

- Plane
  - Data plane: the API surface for data the workload was made to send or receive (HTTPS between components, SQL on 1433, blob reads, AMQP to Service Bus).
  - Control plane: the management surface that configures or operates the resources (AKS API server, management APIs).

Produce a structured security report containing:

- an inventory of every networked resource and its planes
- a network lines-of-sight inventory the user validates interactively
- a findings list grouped by flow and severity with suggested remediations.

Finally, user can volunteer workload requirements and constraints for you to personalize report further.

The only deliverable is the report. This skill never edits the IaC nor offers to apply a remediation.

## Why invoke this skill instead of answering ad hoc

- Every finding is grounded in Microsoft Learn with an enforced citation; ad-hoc training knowledge answers drift.
- The procedure forces direction, plane, and defense-in-depth coverage.
- It captures controls outside the IaC as user-affirmed components.
- It emits structured fields comparable across re-runs.

## Sources of truth

Use only two authoritative sources. Don't invent recommendations from training knowledge; if neither source supports a finding, don't emit it.

1. Microsoft Learn data fetched live via the `microsoftdocs` MCP server. See [references/learn-grounding.md](./references/learn-grounding.md) for source precedence, excluded sources, MCP query patterns, and citation rules.
2. Static analysis of the IaC files using the validators under [Tooling](#tooling).

Every finding must cite at least one Tier 1 Learn URL, the specific file:lines from the IaC, and the MCSB control ID in its References. A finding sourced only from a validator rule still needs a Tier 1 citation explaining why the rule matters for this component.

## Interacting with the user

Never narrate the skill's internal workflow or implementation details in any channel the user sees: chat, question prompts, status updates, or the rendered report. The user asked for a network security review; the machinery that produces it stays invisible.

### Forbidden in any user-visible text

Before sending any user-visible message, scan for these and rewrite if any appear. They are forbidden to appear in any user-visible text.

#### Internal artifact terms

- `scratch file`, `.network-security-review-...`, `validator output directory`
- `step N` (`step 1`–`step 10`), `per references/...`, and `part 1 / 1b / 2` or any other Part/Phase/Sub-step naming for a step's internals
- file or path names of this skill's own files (`SKILL.md`, `references/...`, `assets/...`)
- the equivalents of any of the above in any language. The guard is semantic, not string literal.

Bad: "Step 6 done. Moving to step 7." / "Per SKILL.md, I need to ask you about platform dependencies."
Good: "Grounding done. A few questions about platform dependencies before we continue."

#### No monetary figures

Never attach a monetary figure to an Azure service, SKU, feature, or remediation. The skill doesn't know the user's pricing agreements, region, currency, or consumption, and Microsoft Learn is not a pricing source. This bans currency amounts and ranges, ratios ("3x the cost of"), and qualitative cost claims (cheap, expensive, negligible cost). For example, it's okay to say "higher recurring cost than Standard," but never "adds ~$1.50/hour."

#### No vocabulary from IaC technologies not under review

The IaC scope confirmed in Step 1 fixes the technology: Bicep, Terraform (`.tf` / `.tfvars` / HCL), or a mix. Every user-visible reference to IaC mechanics must match the IaC in scope. For example, don't mention tfvars in a Bicep-only review.

### Asking questions

For every question the agent must ask the user:

- Ask interactively via the host's question facility (e.g., the askQuestions tool in VS Code). Provide concise options for fixed choices (Yes/No, one-of-N, `Intended` / `Unintended` / `Accepted risk`); always allow freeform; multi-select when several apply. In non-English conversations, present option labels bilingually (English literal first, translation in parentheses) and record the English literal so downstream instructions match.
- One question per item, batched into one tool invocation per step. Every dependency row, Network lines-of-sight row, unresolved IaC reference, and "Open questions for the user" entry is its own discrete question. Submit a step's questions together in a single call.
- Ask only questions required by the currently executing step; none from later steps.
- Do not generate downstream content while a blocking question is outstanding.

Non-blocking observations ("FYI, validator X was skipped") stay as plain status messages, not interactive prompts.

### Operating in a non-English conversation

The report and all chat output are written in the user's conversation language.

These items stay in English regardless of conversation language, because the skill procedures references them:

- Report section headings
- Severity labels in findings: `Critical`, `High`, `Medium`, `Low`, `Info`
- Answer literals recorded in tables: `Intended`, `Unintended`, `Accepted risk`, `Y`, `N`, `accepted-risk`.
- Trust-statement IDs (`tr:<name>`), MCSB control IDs, validator rule IDs, Azure resource property names, file paths, and URLs.

Your dialog around these literals, status updates, and interactive question text is in the user's language.

## Sequential steps

When a step's preconditions are not met or a required tool is unavailable, follow [Failure modes](#failure-modes) before stopping or guessing.

Execute steps in order; keep user interaction scoped to the active step.

Working state lives in a scratch file at `.network-security-review-scratch-<YYYYMMDD-HHMM>.md` in the workspace root. Step 1 creates it; every subsequent step writes to it continuously, committing before moving on. Use whatever internal structure you find useful.

The scratch file is internal working state, not a deliverable. The user is never told it exists, never told it is being written, never told it is being updated. See [Forbidden in any user-visible text](#forbidden-in-any-user-visible-text).

### 1. Say hi and set IaC scope

Do three things in this step, in order:

1. **Create the scratch file.** Write `.network-security-review-scratch-<YYYYMMDD-HHMM>.md` in the workspace root with the current UTC timestamp. This is mandatory; subsequent steps assume it exists and write to it. The user is never told about the file.
2. **State the two core thoughts to the user about this process.** Do not wait for acknowledgement on either. Use your own words.
   - Absence of a control in the IaC is treated as the control being missing. A control living outside the IaC must be captured as an explicit dependency the user confirms, or it shows up as a finding. The review is scored against a production bar (real users, real data).
   - This is a long, token-heavy procedure: it walks the full IaC, fetches many Microsoft Learn pages, builds a connectivity graph, runs validators, and outputs a report. Expect a multi-minute run and MCP traffic that scales with IaC size. It's not for quick spot-checks of a single resource.
3. **Confirm the IaC scope.** Confirm which file(s) or folder contains the IaC. If unclear, ask; don't guess. This is the only question in this step. Record the answer in the scratch file.


**Done when:** the scratch file exists at the documented path; the IaC scope is recorded in it; both opening thoughts have been stated to the user.

### 2. Inventory the IaC

Confirm the IaC parses before inventorying. Run the parse-correctness validators under [Tooling](#parse-correctness-validators) (`terraform validate`, `az bicep build`). If either reports errors, surface them and stop. Don't inventory IaC that doesn't parse. If neither tool is installed, skip and note in the scratch file that the inventory lacked parse verification.

Enumerate every networked resource and traffic-relevant feature. Capture for each: resource type, logical name, file path, line number, planes exposed, and the network features and controls that matter.

For every subnet, capture its purpose using the classifier in [references/subnet-purposes.md](./references/subnet-purposes.md). The purpose tag drives per-subnet NSG expectations; without it, NSG findings become generic "is there an NSG?" checks.

Some Azure resources expose separate endpoints per plane governed by different settings; others bundle both planes onto one FQDN. Capture both rows when the service splits them. The per-service Microsoft Learn Private Link page is the source of truth (see [references/concepts.md](./references/concepts.md)).

Resource families to look for (non-exhaustive):

- Edge: Front Door, Application Gateway, Load Balancer (public), API Management (external), Public IPs, DDoS plans.
- Perimeter: Azure Firewall, NVA, NAT Gateway, WAF policies, IP groups, route tables / UDRs.
- Network fabric: virtual networks, subnets, NSGs, ASGs, virtual network peerings, service endpoints, private endpoints, private DNS zones and links, ExpressRoute gateways, VPN gateways.
- Compute with network surface: VMs/VMSS, AKS (CNI, network policy, private cluster, authorized IP ranges), App Service / Functions (vnet integration, access restrictions), Container Apps.
- State stores with network surface: Storage, Key Vault, SQL, Cosmos, Service Bus, Event Hubs, ACR.

**Done when:** parse validators succeeded (or were noted unavailable); every networked resource appears in the inventory with plane(s) and controls; every subnet has a purpose tag (or `unclassified`); undefined IaC references are listed as unresolved.

### 3. Workload coherence check

This skill reviews a workload described in IaC as a coherent system. Before grounding and flow analysis, confirm the inventory represents one; otherwise the reasoning will mislead.

Follow [references/workload-coherence.md](./references/workload-coherence.md) to apply the classification heuristics, pick one of the five classifications, and either proceed as a full workload review or stop and offer the documented choices.

**Done when:** the inventory carries one classification, and either the review continues as a workload review or the user chose a documented alternative.

### 4. Establish dependencies

Many workloads rely on controls supplied by a paired platform landing zone or other external source the skill cannot see from the workload's IaC alone.

After the inventory, identify what is obviously absent but is the kind of thing a platform landing zone typically supplies, then ask the user about the gaps. Follow [references/dependencies.md](./references/dependencies.md).

Skip this step entirely in components-only mode.

**Done when:** every applicable row in the [references/dependencies.md](./references/dependencies.md) table has been asked about and every answer (Yes / No / I don't know) recorded.

### 5. Run static analysis validators

Run every relevant read-only security-rule validator installed (see [Security-rule validators](#security-rule-validators) for invocations). Never run anything that requires Azure credentials, deploys resources, or mutates state. Skip uninstalled tools; don't ask the user to install anything.

Write every validator's output to `.network-security-review-validators-<YYYYMMDD-HHMM>/` in the workspace root.

Capture results to the scratch file under `## Validator findings`, one subsection per validator. Per fired rule: raw rule ID, file:line(s), resource, property, stated remediation.

**Done when:** every available validator was invoked or skipped with a recorded reason; every invocation wrote output to the per-run directory; the scratch file's `## Validator findings` section has one subsection per validator.

### 6. Ground each component family in Microsoft Learn

Fetch the Tier 1 network-security guidance for every distinct component family from step 2.

Fetch the per-service Private Link page for every PaaS family in scope. Record its full sub-resource list and which plane (data, control, or both) each serves. The mapping is not uniform across Azure; don't assume, look it up.

Follow [references/learn-grounding.md](./references/learn-grounding.md) for source precedence, the excluded-sources list, MCP query patterns, and what to extract from each source.

While reading every Learn page, apply the retirement-signal scan in [references/deprecations.md](./references/deprecations.md). Never recommend a feature flagged with a retirement signal; recommend the replacement and fetch its page now so it's available when findings are drafted.

Every finding emitted later must carry an MCSB control ID (when one fits) and a deep link to the most prescriptive Tier 1 page available.

**Done when:** one Tier 1 page is in context per component family and any conflicts with the static tables are recorded in the scratch file. If MCP returns nothing for a family, follow [Failure modes](#failure-modes).

### 7. Verify explicit IaC coverage of network-security properties

A network-security-relevant property not set explicitly in the IaC is itself a defect, even if the Microsoft default is safe. Defaults change; the IaC must show its intent.

For every resource, derive its in-scope property set from Microsoft Learn at review time and check each against the IaC. Each unset property is its own finding.

Follow [references/iac-explicitness.md](./references/iac-explicitness.md). These findings populate a dedicated Implicit IaC defaults section (see [references/report-rules.md](./references/report-rules.md#implicit-iac-defaults)).

**Done when:** every resource was walked against its Learn-derived property set, and every unset network-security-relevant property has an entry in the Implicit IaC defaults section.

### 8. Run both flows

Run north-south first, then east-west. In components-only mode, east-west topology/reachability analysis is skipped but per-resource east-west hardening checks still run (see [components-only mode](./references/workload-coherence.md#components-only-mode)).

1. North-south: follow [references/north-south.md](./references/north-south.md).
2. East-west: follow [references/east-west.md](./references/east-west.md).

If step 6's Microsoft Learn data conflicts with the static procedure tables, Learn wins; emit the finding and cite the URL. For every candidate finding, apply the trust-statement re-scoring rules in [references/dependencies.md](./references/dependencies.md) (skip in components-only mode; no trust statements exist).

Never produce findings about IAM/RBAC, Managed Identities, Key Vault secret hygiene, encryption-at-rest, application authentication, cost, SKU sizing, or general reliability. Those are "out of scope for this review" if the user raises them.

For control-plane endpoints, the boundary is network reachability vs authorization: reachability is in scope, authorization is not. "AKS API server reachable from the Internet" is a finding; "too many people have `Contributor`" is not.

Before finalizing the candidate findings, walk the scratch file's `## Validator findings` section:

- Already in your candidate findings: attach the rule ID (e.g., `Checkov: CKV_AZURE_50`) to References. The Learn citation requirement is unchanged; the rule is supplementary evidence, not a substitute.
- Not in your candidate findings: lift it into a new candidate finding and verify against the Learn page in context for that family, which must support it as a network security control. Apply the in-scope / out-of-scope criteria in [references/iac-explicitness.md](./references/iac-explicitness.md#what-network-security-relevant-means).
- Firing on a property the IaC explicitness review already flagged as unset: that finding covers it; mark the rule covered and don't double list.

For every Critical or High candidate finding, re-fetch the URL it will cite via the `microsoftdocs` MCP server and confirm the prescriptive text supports both the severity and the recommended change. If Microsoft Learn doesn't support it, downgrade or drop it and note the change in the scratch file.

**Done when:** every inventory row has been walked through the relevant procedure table; every validator finding is reconciled; every candidate finding passed the deprecation gate; every Critical/High candidate finding was re-verified against its cited Microsoft Learn page.

### 9. Produce findings

Render findings in the exact shape defined by [references/report-rules.md](./references/report-rules.md): one finding per entry, all required fields populated, grouped by flow (north-south then east-west) then severity (Critical to Info). Every field there is mandatory unless labeled otherwise; don't omit or invent fields.

Before finalizing each finding, run the defense-in-depth pair check per [references/defense-in-depth.md](./references/defense-in-depth.md): when the inventory or finding touches a control in the [Required pairs](./references/defense-in-depth.md#required-pairs) table and only one half is in the IaC, emit a separate finding for the missing partner. Don't invent layers outside that table. Apply the Remediation Azure Policy rule from [report-rules.md](./references/report-rules.md#findings) to every finding.

Every validator rule from step 5 must end up in exactly one place: the Findings section with a Learn citation, an Implicit IaC defaults entry, or explicitly dropped with a one-line reason in the scratch file.

**Done when:** every finding has a populated entry in the report's [Findings section](./references/report-rules.md#findings), the defense-in-depth pair check has run against the inventory, every validator rule from step 5 is recorded, and every required field is filled.

### 10. Offer workload-context refinement

Required as the final step when the inventory was classified as a workload. Skip in components-only mode.

Refinement has two parts. Run them in this order.

#### Workload refinement part 1

Walk the Network lines-of-sight inventory with the user top-down, in row order. Present each row interactively with `Intended` / `Unintended` / `Accepted risk` options and quote the answer verbatim in the row.

- `Unintended`: promote to a Findings entry, score severity per the east-west rules in [east-west.md](./references/east-west.md), quote the user in the Issue text.
- `Accepted risk`: leave the row tagged `accepted-risk` with the reason; don't move to Findings or Suppressed.
- `Intended`: mark `Y` and stop; the completed inventory stays in the report.
- Re-rank only if the answer reveals a wrong tier.

Don't invite the broader workload-context conversation until the inventory is resolved or deferred.

#### Workload refinement part 1b: Open questions

Immediately after part 1, walk the report's "Open questions for the user" section. Present every numbered entry as its own discrete prompt, batched into one tool invocation; skip if the section is empty. If the user defers an item, leave it verbatim and proceed.

#### Hand the report back to the user and gate part 2

After parts 1 and 1b have written every answer into the report, stop; don't start part 2 automatically. Send one short message that, in order: (1) names the report file path; (2) states that the network lines-of-sight and open questions are resolved in the file; (3) asks whether the user wants a refinement pass based on additional functional and non-functional requirements.

If the user answers No, declines, or only wants to review the report, the skill is complete; they can return for the workload-context pass later. If Yes, proceed to part 2.

#### Workload refinement part 2

Reached only after the user explicitly opted in. Invite broader workload context to refine existing findings, using wording such as:

> "The findings so far come from the IaC and Microsoft Learn security data; they don't know your workload's functional or non-functional requirements. Share that context and I'll refine the report against your constraints.
>
> Helpful inputs:
>
> - **Environment**: the report assumed production. If this is a POC, dev/test, or any non-prod environment, say so.
> - **Data sensitivity / regulatory scope**: PII, PHI, PCI, FedRAMP, sovereign-cloud requirements?
> - **Latency / throughput SLOs**: any user-facing or service-to-service latency budgets?
> - **User base and access patterns**: internet-public, B2B partners only, internal corp-only, employee-only?
> - **Cost ceiling or constraints**: any hard limits that rule out certain solutions?
> - **Additional org policies or compensating controls** not visible in IaC or covered by the trust statements.
> - **Known exceptions or accepted risks**: anything security has already signed off on?
>
> Tell me what applies and I'll update the report."

Rules for the refinement loop (open conversation, no fixed procedure):

- Only adjust findings the new info affects. State which changed and why.
- When severity changes, show both values (e.g., `Severity: was High, now Medium (reason)`).
- Don't delete a suppressed finding; move it to a `## Suppressed by workload context` section with the reason and source user input.
- Stay grounded. New recommendations still need a Learn citation and a tradeoffs entry; workload context shifts severity and applicability, not sourcing rules.
- Capture every refinement input in the report header's Assumptions block, attributed to the user.

The loop ends when the user is done; the skill enforces no completion condition.

## Output

Produce a single markdown document. Copy [assets/report-template.md](./assets/report-template.md) as the skeleton, then apply [references/report-rules.md](./references/report-rules.md) to populate each section. Don't invent, reorder, or substitute formats (no JSON, no executive-summary essay).


Write the report to `<scope-name>-network-security-review-<YYYYMMDD-HHMM>.md` in the workspace root. Don't render it inline.

## Tooling

Here is how you'll invoke each tool.

### Microsoft Learn MCP

- Server: `microsoftdocs` (HTTP MCP at `https://learn.microsoft.com/api/mcp`).
- Tools: `microsoft_docs_search` (locate the right page), `microsoft_docs_fetch` (retrieve full content).
- Usage pattern: [references/learn-grounding.md](./references/learn-grounding.md).

### Parse-correctness validators

- `az bicep build --file <file>`: compile Bicep to ARM JSON to confirm parsability and resolve `module` references. Do not run `az deployment ...`.
- `terraform init -backend=false` then `terraform validate`: confirms Terraform parses. Do not run `terraform plan`.

### Security-rule validators

Run during [step 5](#5-run-static-analysis-validators); each tool produces candidate findings reconciled in step 8. Never run anything that requires Azure credentials, deploys resources, or modifies the IaC files. Invocations write into `.network-security-review-validators-<YYYYMMDD-HHMM>/`:

- `tflint --format json --chdir <path> > .network-security-review-validators-<YYYYMMDD-HHMM>/tflint.json`: tflint with the `terraform-provider-azurerm` ruleset.
- `checkov -d <path> --config-file .github/skills/iac-network-security-review/assets/.checkov.yaml --output-file-path .network-security-review-validators-<YYYYMMDD-HHMM>`: Use the skill's curated [skip-list](./assets/.checkov.yaml).

After every run, read the on-disk output to populate the scratch file's `## Validator findings` section.

## Failure modes

When a precondition isn't met, use these rules instead.

### Stop and ask the user, rather than guess, when

Ask every question below via the interactive prompt facility.

- A parameter, variable, `tfvars` value, module input, or referenced output controls a network-security-relevant property (per [iac-explicitness.md](./references/iac-explicitness.md#what-network-security-relevant-means)) and its value isn't visible in the workspace. Ask for the caller or value; don't assume a default.
- The IaC references modules, `.tfvars`, parameter files, or remote state outputs not in the provided path. Ask for help from the user.
- A finding's severity hinges on a platform-supplied control (hub firewall, central DNS, baseline NSGs via policy) not captured as an explicit trust statement. Ask for it; don't infer.

### Tooling unavailable

- **Microsoft Learn MCP not configured.** Stop. Ask the user to install the `microsoftdocs` MCP server. Don't proceed to findings without it or fall back to training knowledge.
- **Microsoft Learn MCP returns no results for a component family.** Stop and tell the user which families are unbacked. Do not fall back to training knowledge. If the user proceeds anyway, add a header disclaimer that grounding was incomplete, list the affected components, and suppress findings for those families.
- **Static-analysis validator not installed.** Skip it silently; don't announce the skip or ask the user to install anything.
