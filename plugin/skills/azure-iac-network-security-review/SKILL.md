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

- [Direction](./references/concepts.md#north-south-vs-east-west-direction)
  - North-south: traffic to/from outside the workload
  - East-west: lateral traffic among its own resources

- [Plane](./references/concepts.md#data-plane-vs-control-plane-plane)
  - Data: the traffic the workload exists to serve
  - Control: the management surface that configures the resources

Produce a structured security report containing:

- an inventory of every networked resource and its planes
- a network lines-of-sight inventory the user validates interactively
- a findings list grouped by flow and severity with suggested remediations
- Microsoft Learn references

Finally, the user can volunteer workload requirements and constraints for you to personalize the report further.

The only deliverable is the report. This skill never edits the IaC nor offers to apply a remediation.

## Why invoke this skill instead of answering ad hoc

- Training data is too risky to ground a security review; every finding is cited to live Microsoft Learn instead.
- A fixed procedure yields consistent, comparable output across re-runs.
- It applies a standardized evaluation that surfaces controls missing from the IaC rather than overlooking them.

## Sources of truth

Use only two authoritative sources. Never invent recommendations from training knowledge.

1. Microsoft Learn data fetched live via the `microsoftdocs` MCP server. See [references/learn-grounding.md](./references/learn-grounding.md) for source precedence, excluded sources, query patterns, and citation rules.
2. Analysis of the IaC via available static analysis tools.

Every finding must cite at least one Tier 1 Learn URL, the IaC file:lines, and the MCSB control ID. A static analysis tool finding still needs a Tier 1 citation explaining why the rule matters.

## Interacting with the user

Never narrate the skill's internal workflow or implementation in any channel the user sees (chat, question prompts, status updates, the report). The user asked for a network security review; the machinery stays invisible.

### Forbidden in any user-visible text

Before sending any user-visible message, scan for these and rewrite if present:

- Internal artifact terms: `scratch file`, `.network-security-review-...`, static analysis output directory.
- Process-internal naming: `step N`, `per references/...`, `part 1 / 2`, or any Part/Phase/Sub-step label.
- File or path names of this skill's own files (`SKILL.md`, `references/...`, `assets/...`).
- The equivalents of any of the above in any language; the guard is semantic, not string literal.

Bad: "Step 6 done. Moving to step 7." / "Per SKILL.md, I need to ask you about platform dependencies."
Good: "Grounding done. I have a few questions about platform dependencies before we continue."

#### No monetary figures

Never attach a monetary figure to any Azure service, SKU, feature, or remediation. The skill doesn't know the user's pricing, currency, or consumption, and Learn is not a pricing source. This bans currency amounts/ranges, ratios ("3x the cost of"), and qualitative cost claims (cheap, expensive, negligible). Qualitative relative cost is fine ("higher recurring cost than Standard"); a number is not ("adds ~$1.50/hour").

#### Match the IaC technology

The scope set in step 1 fixes the technology (Bicep, Terraform/HCL, or a mix). Every user-visible reference to IaC mechanics must match it. E.g., don't mention tfvars in a Bicep-only review.

### Asking questions

- Ask interactively via the host's question facility (e.g., the askQuestions tool in VS Code). Give concise options for fixed choices (Yes/No, one-of-N, `Intended` / `Unintended` / `Accepted risk`), always allow freeform, and multi-select when several apply.
- One question per item, all of a step's questions batched into one tool call. Every dependency row, Network lines-of-sight row, unresolved IaC reference, and "Open questions" entry is its own discrete question.
- Ask only the active step's questions; never any from later steps. Don't generate downstream content while a blocking question is outstanding.

Non-blocking observations ("FYI, static analysis tool X was skipped") stay as plain status messages, not interactive prompts.

### Operating in a non-English conversation

The report and all chat output are written in the user's conversation language, but these literals stay in English because the procedures reference them: report section headings; severity labels (`Critical`, `High`, `Medium`, `Low`, `Info`); table answer literals (`Intended`, `Unintended`, `Accepted risk`, `Y`, `N`, `accepted-risk`); and IDs/names (`tr:<name>`, MCSB control IDs, static analysis rule IDs, Azure property names, file paths, URLs). For fixed-choice options, present labels bilingually (English literal first, translation in parentheses) and record the English literal so downstream instructions match.

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
   - This is a long, token-heavy procedure: it walks the full IaC, fetches many Microsoft Learn pages, builds a connectivity graph, runs static analysis tools, and outputs a report. Expect a multi-minute run and MCP traffic that scales with IaC size. It's not for quick spot-checks of a single resource.
3. **Confirm the IaC scope.** Confirm which file(s) or folder contains the IaC. If unclear, ask; don't guess. This is the only question in this step. Record the answer in the scratch file.


**Done when:** the scratch file exists at the documented path; the IaC scope is recorded in it; both opening thoughts have been stated to the user.

### 2. Inventory the IaC

Confirm the IaC parses before inventorying, then enumerate every networked resource. Follow [references/inventory.md](./references/inventory.md) for the process.

For every subnet, capture its purpose using the classifier in [references/subnet-purposes.md](./references/subnet-purposes.md). The purpose tag drives per-subnet NSG expectations; without it, NSG findings become generic "is there an NSG?" checks.

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

### 5. Run static analysis tools

Run relevant, read-only static analysis tools. Never run anything that requires Azure credentials, deploys resources, or mutates state. Skip uninstalled tools; don't ask the user to install anything. Write every tool's output into `.network-security-review-static-analysis-<YYYYMMDD-HHMM>/` in the workspace root.

Allowed static analysis tools:

- `tflint --format json --chdir <path> > .network-security-review-static-analysis-<YYYYMMDD-HHMM>/tflint.json`: tflint with the `terraform-provider-azurerm` ruleset.
- `checkov -d <path> --config-file <path-to>/assets/checkov.yaml --output-file-path .network-security-review-static-analysis-<YYYYMMDD-HHMM>`: use the skill's curated [skip-list](./assets/checkov.yaml).

After every run, read the on-disk output and capture results to the scratch file under `## Static analysis findings`, one subsection per tool. Per fired rule: raw rule ID, file:line(s), resource, property, stated remediation.

**Done when:** every available tool was invoked or skipped with a recorded reason; every invocation wrote output to the per-run directory; the scratch file's `## Static analysis findings` section has one subsection per tool.

### 6. Ground each component family in Microsoft Learn

Fetch the Tier 1 network security guidance for every distinct component family from step 2. Follow [references/learn-grounding.md](./references/learn-grounding.md) for the grounding process requirements, including the per-page retirement signal search that prevents recommending a deprecated feature.

**Done when:** one Tier 1 page is in context per component family and any conflicts with the static tables are recorded in the scratch file. If MCP returns nothing for a family, follow [Failure modes](#failure-modes).

### 7. Verify explicit IaC coverage of network-security properties

This is the first step that writes final report content, so create the report now: copy [assets/report-template.md](./assets/report-template.md) to `<scope-name>-network-security-review-<YYYYMMDD-HHMM>.md` in the workspace root. From here on, populate its sections as this and later steps produce them, following [references/report-rules.md](./references/report-rules.md).

A network-security-relevant property not set explicitly in the IaC is itself a defect, even if the Microsoft default is safe. Defaults change; the IaC must show its intent.

For every resource, derive its in-scope property set from Microsoft Learn at review time and check each against the IaC. Each unset property is its own finding.

Follow [references/iac-explicitness.md](./references/iac-explicitness.md). These findings populate a dedicated Implicit IaC defaults section (see [references/report-rules.md](./references/report-rules.md#implicit-iac-defaults)).

**Done when:** every resource was walked against its Learn-derived property set, and every unset network-security-relevant property has an entry in the Implicit IaC defaults section.

### 8. Analyze north-south and east-west security

Run north-south first, then east-west. In components-only mode, east-west topology/reachability analysis is skipped but per-resource east-west hardening checks still run (see [components-only mode](./references/workload-coherence.md#components-only-mode)).

1. North-south: follow [references/north-south.md](./references/north-south.md).
2. East-west: follow [references/east-west.md](./references/east-west.md).

After both flows complete, run the [references/finalization.md](./references/finalization.md) pass over the combined candidate set.

**Done when:** every inventory row has been walked through the relevant procedure table; every static analysis finding is reconciled; every candidate finding passed the deprecation gate; every Critical/High candidate finding was re-verified against its cited Microsoft Learn page.

### 9. Produce findings

Render findings in the exact shape defined by [references/report-rules.md](./references/report-rules.md): one finding per entry, all required fields populated, grouped by flow (north-south then east-west) then severity (Critical to Info). Every field there is mandatory unless labeled otherwise; don't omit or invent fields.

Before finalizing each finding, run the defense-in-depth pair check per [references/defense-in-depth.md](./references/defense-in-depth.md): when the inventory or finding touches a control in the [Required pairs](./references/defense-in-depth.md#required-pairs) table and only one half is in the IaC, emit a separate finding for the missing partner. Don't invent layers outside that table. Apply the Remediation Azure Policy rule from [report-rules.md](./references/report-rules.md#findings) to every finding.

Every static analysis rule from step 5 must end up in exactly one place: the Findings section with a Learn citation, an Implicit IaC defaults entry, or explicitly dropped with a one-line reason in the scratch file.

**Done when:** every finding has a populated entry in the report's [Findings section](./references/report-rules.md#findings), the defense-in-depth pair check has run against the inventory, every static analysis rule from step 5 is recorded, and every required field is filled.

### 10. Resolve the network lines-of-sight inventory

Required for a workload review; skip in components-only mode.

Walk the Network lines-of-sight inventory with the user and resolve every row, following [references/lines-of-sight.md](./references/lines-of-sight.md). Present each row interactively as `Intended` / `Unintended` / `Accepted risk`, promote `Unintended` rows to Findings, and record the verbatim answer in each row.

**Done when:** every lines-of-sight row is resolved (`Y` / `accepted-risk`, or promoted to a finding) in the report, with the user's answer quoted in the row.

### 11. Offer workload-context refinement

The final step of a workload review; skip in components-only mode.

Follow [references/refinement.md](./references/refinement.md). You'll resolve the report's open questions, hand the report back and offern an optional requirements-based refinement pass.

**Done when:** the open questions are resolved, the user has been handed the report path and asked about the refinement pass, and any opted-in refinement loop ran to completion.

## Tooling

### Microsoft Learn MCP

- Server: `microsoftdocs` (HTTP MCP at `https://learn.microsoft.com/api/mcp`).
- Tools: `microsoft_docs_search` (locate the right page), `microsoft_docs_fetch` (retrieve full content).
- Usage pattern: [references/learn-grounding.md](./references/learn-grounding.md).

## Failure modes

When a precondition isn't met, use these rules instead.

### Stop and ask the user, rather than guess, when

- A parameter, variable, `tfvars` value, module input, or referenced output controls a network-security-relevant property (per [iac-explicitness.md](./references/iac-explicitness.md#what-network-security-relevant-means)) and its value isn't visible in the workspace. Ask for the caller or value; don't assume a default.
- The IaC references modules, `.tfvars`, parameter files, or remote state outputs not in the provided path.
- A finding's severity hinges on a platform-supplied control (hub firewall, central DNS, baseline NSGs via policy) not captured as an explicit trust statement. Ask for it; don't infer.

### Tooling unavailable

- **Microsoft Learn MCP not configured.** Stop and ask the user to install the `microsoftdocs` MCP server. Don't proceed to findings without it or fall back to training knowledge.
- **Microsoft Learn MCP returns no results for a component family.** Stop and tell the user which families are unbacked. Don't fall back to training knowledge. If the user proceeds anyway, add a header disclaimer that grounding was incomplete, list the affected components, and suppress findings for those families.
- **Static analysis tool not installed.** Skip it silently; don't announce the skip or ask the user to install anything.
