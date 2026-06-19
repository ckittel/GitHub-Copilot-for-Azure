# Finalization pass

Run once, after both flows (SKILL.md step 8) have produced their candidate findings, over the combined set.

## Reconcile static analysis findings

Walk the scratch file's `## Static analysis findings` section:

- **Already in your candidate findings:** attach the rule ID (e.g., `Checkov: CKV_AZURE_50`) to References. The Learn citation requirement is unchanged; the rule is supplementary evidence, not a substitute.
- **Not in your candidate findings:** lift it into a new candidate finding and verify against the Learn page in context for that family, which must support it as a network security control. Apply the in-scope / out-of-scope criteria in [iac-explicitness.md](./iac-explicitness.md#what-network-security-relevant-means).
- **A property the IaC explicitness review already flagged as unset:** that finding covers it; mark the rule covered and don't double list.

## Re-verify Critical and High findings

For every Critical or High candidate finding, re-fetch the URL it will cite via the `microsoftdocs` MCP server and confirm the prescriptive text supports both the severity and the recommended change. If Microsoft Learn doesn't support it, downgrade or drop it and note the change in the scratch file.
