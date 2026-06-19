---
name: azure-iac-network-security-review
description: "Review the network security of Bicep or Terraform infrastructure-as-code (IaC), grounded in Microsoft Learn. USE WHEN: user asks to audit, review, or evaluate the network security of an Azure workload described in IaC. DO NOT USE WHEN: target is anything other than IaC; requested review is IAM/RBAC secret management, application authentication/authorization, cost, SKU sizing, or general reliability concerns; user wants a generic security review."
license: MIT
disable-model-invocation: false
compatibility: Network access required to fetch Microsoft Learn content, access to static analysis tool for IaC files
argument-hint: "<path to bicep/terraform file or folder>"
metadata:
  author: Microsoft
  version: "0.0.0-placeholder"
---

# Azure IaC network security review

Audit the network security posture of Azure resources defined in Bicep or Terraform. Review along two axes:

- Direction
  - North-south is traffic between the workload and anything outside it (internet, on-prem via ExpressRoute or VPN, external customers, partner tenants, sibling workloads).
  - East-west is traffic among the workload's own resources (virtual-network-to-virtual-network within the workload, subnet-to-subnet, service-to-service, pod-to-pod, lateral paths).

- Plane
  - Data plane is the bytes that the workload exists to send or receive (HTTPS to App Gateway, SQL on 1433, blob reads, pod-to-pod, AMQP to Service Bus).
  - Control plane is the management surface that configures or operates the resources (AKS API server, management APIs).

Produce a structured security report containing:

- an inventory of every networked resource and its planes
- a network lines-of-sight inventory the user validates interactively
- a findings list grouped by flow and severity, with suggested remediations.

Finally, follow up with the user to source more workload requirements and constraints for a more personalized report.

The only deliverable is the report. This skill never edits the IaC, never opens a PR, never offers to apply a remediation, never asks the user "want me to make these changes?" Remediation text inside findings describes the change the architect should evaluate; it is documentation, not an action the agent will take.

## Why invoke this skill instead of answering ad hoc

- Every finding gets grounded in data from Microsoft Learn. Ad-hoc answers from training knowledge drift; this skill enforces a Microsoft Learn citation on every finding.
- The procedure forces direction coverage, plane coverage, and a defense-in-depth check. An ad-hoc review almost always misses some aspect of the network security posture.
- Security controls that exist outside of the presented IaC get captured as named, user-affirmed components rather than silently assumed.
- The output uses structured fields so it's comparable across re-runs.

## Sources of truth

Use only two authoritative sources. Do not invent recommendations from training knowledge; if neither source supports a finding, do not emit it.

1. Microsoft Learn data fetched live via the `microsoftdocs` MCP server. See [references/learn-grounding.md](./references/learn-grounding.md) for the source precedence, excluded sources, MCP query patterns, and citation rules.
2. Static IaC analysis of the IaC files themselves using the validators listed under [Tooling](#tooling).

Every finding must cite at least one Tier 1 Learn URL and the specific file:line(s) from the IaC. The MCSB control ID must also appear in the References. A finding sourced only from a validator rule must still be backed by a Tier 1 citation explaining why the rule matters for this component.

## Interacting with the user

Never narrate the skill's internal workflow implementation details or workflow language. This applies to every channel the user sees: chat messages, interactive question prompts, status updates, and the rendered report. The user asked for a network security review of their IaC; the machinery that produces it stays invisible to them.

### Forbidden in any user-visible text

Before sending any message to the user (chat, status update, interactive prompt text, report body), scan it for these and rewrite if any appear. They are forbidden to appear in any user-visible text.

#### Internal artifact terms

- `scratch file`, `scratch`, `.network-security-review-scratch-...`
- `validator output directory`, `.network-security-review-validators-...`
- `step N`, `step 1` through `step 10`, `per SKILL.md`, `per references/...` as it relates to this skill's instructions
- part 1, part 1b, part 2, "workload refinement part ...," or any other "Part / Phase / Sub-step" naming the skill uses to organize a step's internals
- file or path names of this skill's own files (`SKILL.md`, `references/...`, `assets/...`)
- the equivalents of any of the above in whatever language the conversation is in. The guard is semantic, not literal-string.

Bad: "I have sufficient Microsoft Learn grounding. Now I'll write the scratch file and the final report."
Good: "I have the Microsoft Learn data I need. Writing the report now."

Bad: "Step 6 done. Moving to step 7."
Good: "Grounding done. A few questions about platform dependencies before I continue."

Bad: "Per SKILL.md, I need to ask you about platform dependencies."
Good: (silence; status updates are optional, not mandatory)

Bad: "Part 1 walks the Network lines-of-sight table with you to mark each row Intended / Unintended / Accepted risk; Part 1b walks the Open questions; Part 2 offers to extend with workload-specific context you supply."
Good: "Next: We'll go over the discovered network lines-of-sight with you so you can mark each Intended, Unintended, or Accepted risk, then any open questions, then offer to refine the findings against your workload's requirements."

#### No monetary figures

Also forbidden in any user-visible text: any monetary figure attached to an Azure service, SKU, feature, or remediation. The skill does not know the user's pricing agreements, region, currency, commitment tier, or consumption pattern, and Microsoft Learn is not a pricing source. Concrete examples of what must never appear: dollar (or any-currency) amounts (`$1.50/hour`, `~$200/month`, `¥10,000/月`, `€0.04/GB`), price ranges (`$X-$Y`), price ratios (`roughly 3x the cost of...`), free-tier claims (`free`, `no additional cost`, `included at no charge`), or qualitative magnitude claims tied to price (`cheap`, `expensive`, `negligible cost`). This applies whether the figure is sourced from training data, inferred from SKU names, or stated as an approximation. 

Bad: "Tradeoffs: Premium SKU adds ~$1.50/hour vs. Standard."
Good: "Tradeoffs: Premium SKU has a higher recurring cost than Standard."

#### No vocabulary from IaC technologies not under review

The IaC scope confirmed in Step 1 fixes the flavor for the rest of the review: either Bicep or Terraform (`.tf` / `.tfvars` / HCL) or a mix. Every user-visible reference to IaC mechanics must match the IaC in scope.

Bad (Bicep-only review): "No upstream Bicep parameter files or tfvars-equivalent overrides were supplied that would change the resource shapes reviewed here."
Good (Bicep-only review): "No Bicep parameter files or parameter overrides were supplied that would change the resource shapes reviewed here."
Good (flavor-neutral when the mechanism distinction does not matter): "No external parameter overrides were supplied that would change the resource shapes reviewed here."

### Asking questions

This skill blocks progress on several questions. For every question the agent needs an answer to before it can proceed:

- Ask interactively. Use the host's interactive question facility (e.g., the askQuestions tool in VS Code, or the equivalent on whichever host the agent runs on). Provide concise options whenever the answer is a fixed choice (Yes/No, one-of-N classification, `Intended` / `Unintended` / `Accepted risk`); allow freeform for every option. Multi-select when the user can pick several at once. When the conversation is not in English, present option labels bilingually with the English literal first and a translation in parentheses, and record the English literal in the scratch file and the report row so downstream branching matches.
- Do not bury blocking questions in prose or output files. Never embed a question inside a long status update where the user has to scroll back to find it. Never list multiple questions inline and expect the user to answer them all in one paragraph.
- One question per item, batched into one tool invocation per step. Every dependency row, every Network lines-of-sight row, every unresolved IaC reference, every entry written into the report's `Open questions for the user` section is its own discrete question with its own options. Submit all of a step's questions together in a single call to the interactive facility so the user sees one ordered list of distinct questions to work through.
- Current-step boundary: ask only questions required by the step that is currently executing. Do not ask questions from any later step in advance.
- Do not generate downstream content while a blocking question is outstanding.
- Mirror every answer into the scratch file and the report.

Non-blocking observations ("FYI, validator X was skipped because not installed") stay as plain status messages and do not use the interactive prompt.

### Operating in a non-English conversation

The report and all chat output are written in the user's conversation language.

These items stay in English regardless of conversation language, because the skill procedures references them:

- Report section headings.
- Severity labels in findings: `Critical`, `High`, `Medium`, `Low`, `Info`.
- Answer literals recorded in tables: `Intended`, `Unintended`, `Accepted risk`, `Y`, `N`, `accepted-risk`.
- Trust-statement IDs (`tr:<name>`), MCSB control IDs, validator rule IDs, Azure resource property names, file paths, and URLs.

Prose around these literals, status updates, and interactive question text is in the user's language.

## Sequential steps

When a step's preconditions are not met or a required tool is unavailable, follow [Failure modes](#failure-modes) before stopping or guessing how to proceed.

Execute steps in order and keep user interaction scoped to the active step.

Working state lives in a scratch file at `.network-security-review-scratch-<YYYYMMDD-HHMM>.md` in the workspace root. Step 1 creates it; every subsequent step writes to it continuously, not at the end of the run. At a minimum, every step commits to the file before the agent moves to the next step; many steps benefit from more frequent updates. Use whatever structure inside the file you find useful.

The scratch file is internal working state, not a deliverable. The user is never told it exists, never told it is being written, never told it is being updated. See [Forbidden in any user-visible text](#forbidden-in-any-user-visible-text).

### 1. Say hi and set IaC scope

Do three things in this step, in order:

1. **Create the scratch file.** Write `.network-security-review-scratch-<YYYYMMDD-HHMM>.md` in the workspace root with the current UTC timestamp. This is a mandatory action, not background bookkeeping; subsequent steps assume the file exists and write to it as they go. The user is never told about the file.
2. **State the two core thoughts to the user about this process.** Do not wait for acknowledgement on either. Use your own words.
   - Absence of a control in the IaC is treated as the control being missing. If a control lives outside the IaC, it has to be captured as an explicit dependency the user confirms; otherwise it shows up as a finding. The review is scored against a production bar (real users, real data); if this is a dev/test or POC environment, the user can say so during the refinement loop.
   - This is a long, token-heavy procedure. The review walks the full IaC, fetches many Microsoft Learn pages for grounding, builds a connectivity graph, runs validators, and outputs a report. Expect a multi-minute run and substantial MCP traffic to Microsoft Learn. Runtime and token usage scale with the size and complexity of the IaC. This skill is not appropriate for quick spot-checks of a single resource.
3. **Confirm the IaC scope.** Confirm which file(s) or folder contains the IaC. If unclear, ask; do not guess. This is the only question to the user in this step. Record the answer in the scratch file.


**Done when:** the scratch file exists at the documented path; the IaC scope is recorded in it; both opening thoughts have been stated to the user.

### 2. Inventory the IaC

Confirm the IaC parses before inventorying. Run the parse-correctness validators listed under [Tooling](#parse-correctness-validators) (`terraform validate` for Terraform paths, `az bicep build` for Bicep). If either reports errors, surface them to the user and stop. You shouldn't inventory IaC that does not parse. However, if neither tool is installed, skip and note the gap in the scratch file that the inventory was built without parse verification.

Enumerate every networked resource and every traffic-relevant feature. Capture for each: resource type, logical name, file path, line number, which plane(s) the resource exposes, and the network features and controls that matter.

For every subnet, capture its purpose using the classifier in [references/subnet-purposes.md](./references/subnet-purposes.md). The purpose tag drives the per-subnet NSG expectations; without it, NSG findings become generic "is there an NSG?" checks.

Some Azure resources expose separate endpoints per plane governed by different settings; others bundle both planes onto one FQDN. Capture both rows when the service splits them. The per-service Microsoft Learn Private Link page is the source of truth; see [references/concepts.md](./references/concepts.md) for the breakdown.

Resource families to look for (non-exhaustive):

- Edge: Front Door, Application Gateway, Load Balancer (public), API Management (external), Public IPs, DDoS plans.
- Perimeter: Azure Firewall, NVA, NAT Gateway, WAF policies, IP groups, route tables / UDRs.
- Network fabric: virtual networks, subnets, NSGs, ASGs, virtual network peerings, service endpoints, private endpoints, private DNS zones and links, ExpressRoute gateways, VPN gateways.
- Compute with network surface: VMs/VMSS, AKS (CNI mode, network policy, private cluster, authorized IP ranges), App Service / Functions (virtual network integration, access restrictions), Container Apps environments.
- State stores with network surface: Storage, Key Vault, SQL, Cosmos, Service Bus, Event Hubs, ACR.

**Done when:** parse-correctness validators succeeded (or were unavailable and noted); every networked resource in the path appears in the inventory with plane(s) and network controls; every subnet has a purpose tag (or `unclassified`); IaC references not defined in the path are listed as unresolved (handled in [Failure modes](#failure-modes)).

### 3. Workload coherence check

This skill reviews a workload described in IaC as a coherent system. Before performing Microsoft Learn grounding and flow analysis, confirm the inventory actually represents one. If it does not, the reasoning will be misleading.

Follow [references/workload-coherence.md](./references/workload-coherence.md) to apply the classification heuristics, pick one of the five classifications, and either proceed as a full workload review or stop and offer the user the documented choices. Do not pick a mode for the user.

**Done when:** the inventory carries one classification, and either the review continues as a workload review or the user has chosen one of the documented alternatives.

### 4. Establish dependencies

Many workloads rely on controls supplied by a paired platform landing zone or other external source. The skill cannot see those from the workloads's IaC alone.

After the inventory, identify what is obviously absent from the IaC but is the kind of thing a platform landing zone typically supplies. Then ask the user about the gaps. Follow [references/dependencies.md](./references/dependencies.md).

Skip this step entirely in components-only mode.

**Done when:** every row in the [references/dependencies.md](./references/dependencies.md) table that applies to this inventory has been asked about to the user and every answer (Yes / No / I don't know) is recorded.

### 5. Run static analysis validators

Run the available read-only IaC validators against the provided path.

Run every relevant security-rule validator installed on the system listed in the tooling section. Never run anything that requires Azure credentials, deploys resources, or mutates state. See [Security-rule validators](#security-rule-validators) for per-tool invocations. Skip uninstalled tools; do not ask the user to install anything.

Write every validator's output to `.network-security-review-validators-<YYYYMMDD-HHMM>/` in the workspace root (same timestamp as the scratch file and final report).

Capture results to the scratch file under `## Validator findings`, one subsection per validator. For each rule that fired: raw rule ID, file:line(s), resource, property, the rule's stated remediation.

**Done when:** every available validator has been invoked or skipped with a recorded reason; every invocation wrote output to the per-run directory; the scratch file's `## Validator findings` section has one subsection per validator.

### 6. Ground each component family in Microsoft Learn

Before running the flow procedures, fetch the Tier 1 network-security guidance for every distinct component family found in step 2.

Fetch the per-service Private Link page for every PaaS family in scope. Record the full sub-resource list the service exposes and which plane (data, control, or both) each sub-resource serves. The mapping is not uniform across Azure: some services bundle both planes onto a single sub-resource, some split them, some have multiple control-plane sub-resources. Do not assume; look it up.

Follow [references/learn-grounding.md](./references/learn-grounding.md) for:

- The source precedence and the excluded sources list.
- The MCP query patterns to use
- What to extract from each source

While reading every Learn page, apply the retirement-signal scan in [references/deprecations.md](./references/deprecations.md). Any feature flagged with a retirement signal must not be recommended; recommend the replacement instead and fetch the replacement's page now so it is available when findings are drafted.

Every finding emitted later must carry both an MCSB control ID (when one fits) and a deep link to the most prescriptive Tier 1 page available.

**Done when:** One Tier 1 page is in context for each component family, and any conflicts between the static tables and live Tier 1 are recorded in the scratch file. Do not chain searches looking for confirmation; one prescriptive page per family is sufficient. If MCP returns nothing for a family, follow [Failure modes](#failure-modes).

### 7. Verify explicit IaC coverage of network-security properties

A network-security-relevant property that is not set explicitly in the IaC is itself a defect, regardless of whether the Microsoft default is safe. Defaults change; the IaC must always show its intent.

For every resource in the inventory, derive its in-scope property set from Microsoft Learn at review time and check each property against the IaC. Each unset property is its own finding.

Follow [references/iac-explicitness.md](./references/iac-explicitness.md) for the property-set derivation, the severity rules, and the interaction with the flow steps. Findings emitted here populate a dedicated Implicit IaC defaults section of the report (see [references/report-rules.md](./references/report-rules.md#implicit-iac-defaults)), separate from the Findings section the flow steps populate.

**Done when:** every resource in the inventory has been walked against its Learn-derived property set, and every unset network-security-relevant property has an entry in the Implicit IaC defaults section.

### 8. Run both flows

Run north-south first, then east-west. In components-only mode, the east-west topology and reachability analysis is skipped, but per-resource east-west hardening checks still run; see [components-only mode](./references/workload-coherence.md#components-only-mode) for the full split.

1. North-south: follow [references/north-south.md](./references/north-south.md).
2. East-west: follow [references/east-west.md](./references/east-west.md).

If a check from step 6's Microsoft Learn data conflicts with the static procedure tables, Learn wins; emit the finding and cite the URL. For every candidate finding, apply the trust-statement re-scoring rules in [references/dependencies.md](./references/dependencies.md). Skip in components-only mode; no trust statements exist.

Never produce findings about IAM/RBAC, Managed Identities, Key Vault secret hygiene, encryption-at-rest, application authentication, cost, SKU sizing, or general reliability topics. They are "out of scope for this review" if the user raises them.

For control-plane endpoints, the boundary is network reachability vs authorization: reachability is in scope, authorization is not. "AKS API server reachable from the Internet" is a finding; "too many people have `Contributor` on the AKS resource" is not.

Before finalizing the candidate findings the flow walks produced, walk the `## Validator findings` section of the scratch file:

- A validator rule whose subject is already in your candidate findings: attach the rule ID (e.g., `Checkov: CKV_AZURE_50`) to the finding's References. The Learn citation requirement is unchanged; the validator rule is supplementary evidence, not a substitute.
- A validator rule whose subject is not in your candidate findings: lift it into a new candidate finding. Verify it against the Learn page already in context for that resource family. The Learn page must support the rule as a network security control. Apply the in-scope / out-of-scope criteria in [references/iac-explicitness.md](./references/iac-explicitness.md#what-network-security-relevant-means).
- A validator rule that fires on a property the IaC explicitness review already flagged as unset: the explicitness finding already covers it; mark the validator rule as covered and do not double-emit.

For every candidate finding the flows produced at Critical or High severity, re-fetch the URL the finding will cite via the `microsoftdocs` MCP server and confirm the prescriptive text supports both the severity and the recommended change. If Microsoft Learn doesn't support the finding, downgrade it or drop it and note the change in the scratch file.

**Done when:** every inventory row from step 2 has been walked through the relevant procedure table at least once; every validator finding from step 5 has been reconciled; every candidate finding has passed the deprecation gate; every Critical or High candidate finding has been re-verified against its cited Microsoft Learn page.

### 9. Produce findings

Render findings in the exact shape defined by [references/report-rules.md](./references/report-rules.md): one finding per entry, all required fields populated, grouped by flow (north-south then east-west) then by severity (Critical, High, Medium, Low, Info). Every field defined there is mandatory unless otherwise labeled; do not omit fields or invent new ones.

Before finalizing each finding, run the defense-in-depth pair check per [references/defense-in-depth.md](./references/defense-in-depth.md): when the inventory or the finding touches a control in the [Required pairs](./references/defense-in-depth.md#required-pairs) table and only one half is present in the IaC, emit a separate finding for the missing partner. Do not invent second layers outside that table (same-layer alternatives and over-recommendations are listed there too). Apply the Remediation Azure Policy rule from [report-rules.md](./references/report-rules.md#findings) to every finding.

Every validator rule captured in step 5 must end up in exactly one of three places by the end of this step:

1. In the Findings section, with a Learn citation
2. Covered by an Implicit IaC defaults entry
3. Explicitly dropped, with a one-line reason in the scratch file.

**Done when:** every finding from step 8 has a populated entry in the report's [Findings section](./references/report-rules.md#findings), the defense-in-depth pair check has been run against the inventory, every validator rule from step 5 is recorded, and every required field is filled.

### 10. Offer workload-context refinement

Required as the final step when the inventory was classified as a workload. Skip in components-only mode.

Refinement has two parts. Run them in this order.

#### Workload refinement part 1

Walk the Network lines-of-sight inventory with the user top-down, in the order the rows were written. Present the rows interactively with `Intended` / `Unintended` / `Accepted risk` as options for each row. Quote each answer verbatim in the row.

- `Unintended`: promote to a Findings entry, score severity per the east-west rules in [east-west.md](./references/east-west.md), quote the user in the Issue text.
- `Accepted risk`: leave the row in the inventory tagged `accepted-risk` with the reason. Do not move to Findings or Suppressed.
- `Intended`: mark `Y` and stop. The completed inventory stays in the report.
- Re-rank only if the user's answer reveals a wrong tier.

Do not invite the broader workload-context conversation until the inventory is resolved or the user defers it.

#### Workload refinement part 1b: Open questions

Immediately after part 1, walk the report's `Open questions for the user` section. Present every numbered entry as its own discrete prompt via the interactive question facility, batched into one tool invocation. If the section is empty, skip this sub-step.

If the user defers an item, leave it in Open questions verbatim and proceed.

#### Hand the report back to the user and gate part 2

After parts 1 and 1b have written every answer into the report, stop. Do not start part 2's questions automatically. Send one short message to the user that does three things in this order:

1. Names the report file path so the user can open it.
2. States plainly that the network lines-of-sight and open questions are resolved in the file.
3. Asks, whether the user wants to continue with a refinment pass based on additional functional and non-functional requirements for their workload.

If the user answers No, declines, or only says they want to review the report, the review is complete. Do not start the part 2 inputs prompt. The user can return and ask for the workload-context pass on their own.

If the user answers Yes, proceed to part 2.

#### Workload refinement part 2

Reached only after the user has explicitly opted in at the previous sub-section. Invite broader workload context to refine existing findings. Use wording such as:

> "The findings so far come from the IaC and the Microsoft Learn security data. They don't know anything about your workload's functional or non-functional requirements. If you want to share that context, I'll refine the report against your provided constraints.
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

Rules for the refinement loop (open conversation; no fixed procedure):

- Only adjust findings the new info affects. State which findings changed and why.
- When severity changes, show both values (e.g., `Severity: was High, now Medium (reason)`).
- When a finding is suppressed, do not delete it. Move it to `## Suppressed by workload context` section with the reason and the user input that drove it.
- Stay grounded. New recommendations still need a Learn citation and a tradeoffs entry. Workload context shifts severity and applicability, not sourcing rules.
- Capture every refinement input in the report header's Assumptions block, attributed to the user.

The loop ends when the user is done; the skill enforces no completion condition.

## Output

Produce a single markdown document. Copy [assets/report-template.md](./assets/report-template.md) as the starting skeleton, then apply the rules in [references/report-rules.md](./references/report-rules.md) to populate each section. Don't invent additional sections, reorder them, or substitute formats (no JSON, no executive-summary essay).

The report must be self-contained. Never write the names of this skill's files (`SKILL.md`, `references/*.md`, `assets/...`) or step numbers ("per SKILL.md step N") into the rendered report. Assume the report reader has no access to this skill's files. References fields cite only external sources (Microsoft Learn URLs, Azure Policy built-in URLs); never the skill's own files. Carry rule rationale into the report in your own words.

Strip the locale from every Microsoft Learn URL emitted into the report. During grounding the skill uses Microsoft Learn URLs with `/en-us` in the path so the agent reads English content; when writing the URL into the report, remove the `/en-us` segment so the reader's lands on Microsoft Learn in their own locale. For example, cite `https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-network-security#ns-2`, not `https://learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-network-security#ns-2`. The rule applies only to URLs in the emitted report; scratch-file URLs and URLs the agent fetches use `/en-us`.

Write the report to `<scope-name>-network-security-review-<YYYYMMDD-HHMM>.md` in the workspace root, where `<scope-name>` is the inferred workload or scope name and `<YYYYMMDD-HHMM>` is the current UTC timestamp. Do not render the report inline. Point the user at the file path and summarize in one or two sentences.

### Reporting stance

Treat the report as a discovery document for a security critical review. Bias the output entirely toward what is wrong or unverified. Specifically:

- Report only what is broken, missing, weak, or unverified. Do not list controls that are correctly configured.
- Do not soften language. No "consider," "you may want to," "it might be worth." State the issue, the impact, and the required change.
- Do not add summaries that frame the posture positively ("overall the architecture is solid, with a few gaps..."). The user is here for the gaps.
- Do not editorialize on the architect's intent or skill. Address findings to the IaC, not the user.

Deliver a direct review. Complete, brutally honest feedback is the value.

### Example shape

See [assets/report-template.md](./assets/report-template.md) for the empty report skeleton to copy.

## Tooling

Ground findings in two authoritative sources (see [Sources of Truth](#sources-of-truth)): the `microsoftdocs` MCP server and read-only static IaC validators.

This section documents how to invoke each tool.

### Microsoft Learn MCP

- Server: `microsoftdocs` (HTTP MCP at `https://learn.microsoft.com/api/mcp`).
- Tools: `microsoft_docs_search` (locate the right page), `microsoft_docs_fetch` (retrieve full content).
- Usage pattern: [references/learn-grounding.md](./references/learn-grounding.md).

### Parse-correctness validators

Run during [step 2](#2-inventory-the-iac). Failures are reported to the user and the review stops; you shouldn't inventory IaC that does not parse.

- `az bicep build --file <file>`: compile Bicep to ARM JSON to confirm parsability and resolve `module` references locally. Do not run `az deployment <scope> what-if` or `az deployment <scope> validate`.
- `terraform init -backend=false` followed by `terraform validate`: confirms Terraform parses. Do not run `terraform plan`, which requires auth and resolves runtime data.

### Security-rule validators

Run during [step 5](#5-run-static-analysis-validators). Each produces candidate findings the flow walks reconcile against in step 8. Never run anything that requires Azure credentials, deploys resources, or modifies the IaC files.

Tool invocations written into `.network-security-review-validators-<YYYYMMDD-HHMM>/`:

- `tflint --format json --chdir <path> > .network-security-review-validators-<YYYYMMDD-HHMM>/tflint.json`: tflint with the `terraform-provider-azurerm` ruleset.
- `checkov -d <path> --config-file .github/skills/iac-network-security-review/assets/.checkov.yaml --output-file-path .network-security-review-validators-<YYYYMMDD-HHMM>`: Checkov with the skill's curated [skip-list](./assets/.checkov.yaml) (IAM, secrets, encryption-at-rest, audit policy checks suppressed). Bundled config writes both CLI and JSON; `--output-file-path` redirects the JSON into the per-run directory as `results_json.json`. If the user has a repo-root `.checkov.yaml`, prefer theirs but ensure JSON output to the per-run directory.

After every run, read the on-disk output file to populate the scratch file's `## Validator findings` section. Every rule that fires must end up in the Findings section with a Learn citation, covered by an Implicit IaC defaults entry, or explicitly dropped in the scratch file ([step 9 coverage rule](#9-produce-findings)).

## Failure modes

The sections above describe the happy path. When a precondition is not met, follow these rules instead.

### Stop and ask the user, rather than guess, when

Ask every question below via the interactive prompt facility.

- A parameter, variable, `tfvars` value, module input, or referenced output controls a network-security-relevant property (per [iac-explicitness.md](./references/iac-explicitness.md#what-network-security-relevant-means)) and its value is not visible in the provided workspace. Ask for the caller or the value; do not assume a default.
- The IaC references modules, `.tfvars` files, parameter files, or remote state outputs that are not in the provided path.
- A finding's severity hinges on a platform-supplied control (hub firewall, central DNS, baseline NSGs via policy) that has not been captured as an explicit trust statement. Ask for the trust statement; do not infer.

### Tooling unavailable

- **Microsoft Learn MCP not configured.** Stop. Ask the user to install the `microsoftdocs` MCP server. Do not proceed to findings without it; do not fall back to training knowledge.
- **Microsoft Learn MCP returns no results for a component family.** Stop and tell the user which families are unbacked. Do not silently fall back to training knowledge. If the user wants to proceed anyway, emit a header disclaimer that grounding was incomplete and list the affected components; suppress findings for those families.
- **Static-analysis validator is not installed.** Skip it without announcing the skip in chat and without asking the user to install anything.
