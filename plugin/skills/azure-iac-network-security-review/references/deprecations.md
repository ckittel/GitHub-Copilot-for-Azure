# Don't recommend deprecated, retiring, or superseded features

This skill must never recommend a feature that Microsoft has deprecated, marked retiring, marked legacy, or superseded with a successor even when:

- Microsoft Learn still documents the deprecated feature in detail.
- A static-analysis validator still finds it and recommends "configure X" where X is the deprecated thing.
- The deprecated feature appears in the existing IaC and the user has not yet been told it is on the retirement path.

The agent detects deprecation on the fly while grounding.

## Live detection during grounding

While fetching Learn pages, scan every page section the skill is about to draw a recommendation from. Treat any of the following as a hard signal that the feature on that page is not to be recommended:

- A retirement banner or callout at the top of the page or section ("This feature is being retired," "Support for X ends on `<date>`," "X is in maintenance mode," "X is being deprecated").
- Prose phrased as "we recommend migrating to," "use Y instead," "Y is the recommended replacement for X," "no longer recommended," "superseded by Y," "legacy `<feature>`."
- A "What's new" or "Retirement notices" entry under the service's documentation that references the feature.
- The page's existence as the "migration guide from X to Y"

When any of these fires for the specific feature the recommendation would name:

1. Stop drafting the recommendation that uses the deprecated feature.
2. Search and fetch the replacement's Learn page. The banner or prose typically names the replacement; if not, search `<service> <feature-area> replacement` or `migrate from <X> to <Y>`.
3. Recommend the replacement if a proper fit for the scenario. Cite the replacement's page. Do not mention the deprecated feature in the report at all.
4. Record the deprecation in the scratch file under a `## Deprecations encountered` section: deprecated feature name, replacement, URL of the retirement notice. This is a reviewer-facing audit trail; it never appears in the final report unless the IaC itself uses the deprecated feature.

If a page documents multiple features side by side and the retirement banner covers only one of them, exclude only that one, not the page.

## When the IaC uses a deprecated feature

When step 2 inventory or any later walk finds a resource shape that grounding has flagged as deprecated, that is itself a finding regardless of any other defect on the same resource. Emit it with:

- **Issue**: name the deprecated feature, the retirement signal observed (quote the banner or prose verbatim), and the replacement.
- **Remediation**: the replacement, with the property changes required to switch.
- **References**: the retirement notice URL and the replacement's Learn page.

## When a validator recommends a deprecated feature

A validator rule may fire correctly but recommend a deprecated control as the fix. Lift the rule into a finding because the gap is real, but rewrite the Remediation to the replacement the live grounding identified. The validator's stated remediation does not govern; the Learn-grounded recommendation does. Note the rewrite in the scratch file's `## Validator findings` section so the disposition is auditable.

## What this rule does not authorize

- Inventing deprecations from training knowledge. Every claim that a feature is deprecated must be backed by a Learn page fetched during this review. If grounding does not surface a retirement signal, the feature is treated as current.
