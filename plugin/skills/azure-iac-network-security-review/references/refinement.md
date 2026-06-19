# Workload-context refinement

This step runs after the Network lines-of-sight inventory has been resolved with the user. It resolves any remaining open questions, hands the report back, and gates an optional requirements-based refinement pass. Skipped in components-only mode. It has two parts plus a gate; keep all interaction scoped to the part currently running.

## Part 1: resolve open questions

Walk the report's "Open questions for the user" section. Present every numbered entry as its own discrete prompt, batched into one tool invocation; skip if the section is empty. If the user defers an item, leave it verbatim and proceed.

## Gate: hand the report back before part 2

After the open questions have been written into the report, stop; don't start part 2 automatically. Send one short message that, in order: (1) names the report file path; (2) states that the network lines-of-sight and open questions are resolved in the file; (3) asks whether the user wants a refinement pass based on additional functional and non-functional requirements.

If the user answers No, declines, or only wants to review the report, the skill is complete; they can return for the workload-context pass later. If Yes, proceed to part 2.

## Part 2: refine against workload requirements

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
