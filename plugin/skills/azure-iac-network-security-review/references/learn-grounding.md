# Microsoft Learn grounding via MCP

This skill grounds every finding in Microsoft Learn data fetched live via the `microsoftdocs` MCP server. Learn has multiple authoritative document sets for network security; following the precedence below is mandatory.

Use the `en-us` locale for every Learn URL you fetch; auto-translated pages can lose technical precision.

## Source precedence

Tier 1 (authoritative):

1. **Microsoft Cloud Security Benchmark (MCSB) v2, Network Security family.** `learn.microsoft.com/en-us/security/benchmark/azure/mcsb-v2-network-security`. Controls NS-1 through NS-10. Every finding this skill emits should map to a specific NS-* control. If a finding cannot be mapped to MCSB, double-check that it is in fact a network-security finding and not something out of scope.
2. **Well-Architected Framework service guide, Security section.** `learn.microsoft.com/en-us/azure/well-architected/service-guides/<service>`. Strongest per-service source for architectural reasoning and the tradeoffs call-outs that populate the required Tradeoffs field on every finding.

Tier 2 (supplementary):

3. **Well-Architected Framework Security pillar, networking guide.** `learn.microsoft.com/en-us/azure/well-architected/security/networking` (SE:06) plus the segmentation guide `learn.microsoft.com/en-us/azure/well-architected/security/segmentation` (SE:04). Use for workload level principles.
4. **Per-service reference docs**, especially "Network security" / "Use private endpoints" / "Configure firewall rules" pages under `learn.microsoft.com/en-us/azure/<service>/`. Use when the Well-Architected Framework service guide does not cover a specific feature.
5. **Zero trust deployment guide, Networks pillar.** `learn.microsoft.com/en-us/security/zero-trust/deploy/networks`. Use for assume-breach framing.
6. **Azure security fundamentals, network best practices.** `learn.microsoft.com/en-us/azure/security/fundamentals/network-best-practices`. Basics and glossary.
7. **Azure Policy built-ins, Network category.** `learn.microsoft.com/en-us/azure/governance/policy/samples/built-in-policies#network`. Cite when naming a built-in policy that would enforce the recommendation workload wide, as a remediation reinforcement.

## Excluded sources

Do not cite, fetch for guidance, or quote from these, even when `microsoft_docs_search` returns them as top-ranked results.

- **Per-service Azure Security Baselines.** `learn.microsoft.com/en-us/security/benchmark/azure/baselines/<service>-security-baseline`. Every published baseline carries a warning that says: *"This security baseline ... may contain outdated guidance."* The risk of citing stale security guidance outweighs is use.
- **MCSB v1 deep links.** `learn.microsoft.com/en-us/security/benchmark/azure/mcsb-network-security` and other `mcsb-*` URLs without the `-v2-` segment. Use the v2 URL.

If `microsoft_docs_search` returns one of the above as the top hit, discard it and re-search with terms that bias toward the Well-Architected Framework service guide or the per-service docs.

Microsoft Tech Community blog posts, Azure team blogs, MVP articles, and third-party guidance are not authoritative for this skill, regardless of how good they look. They can inform reasoning; they cannot back a finding.

## MCP server

- Server name: `microsoftdocs`
- Tools available:
  - `microsoft_docs_search`: keyword/semantic search; returns ranked Learn URLs with short excerpt chunks. Use only to pick the right URL. The excerpts are partial and can miss the prescriptive sections, retirement notices, and tables this skill depends on. Never ground a finding on a search snippet.
  - `microsoft_docs_fetch`: retrieves the full page content for the URL. Always call this on the page you intend to cite.

If the server is not configured, ask the user to configure it. Do not proceed without it.

## Grounding loop

For the inventory built in SKILL.md step 2:

1. **De-duplicate to component families.** Five storage accounts become one query batch. Two AKS clusters become one query batch.
2. **For each family, fetch all available Tier 1 sources, in order:**
   1. **MCSB v2**: search `microsoft cloud security benchmark v2 network security` once per review (not once per family). Fetch the full `mcsb-v2-network-security` page once via `microsoft_docs_fetch` and reuse the NS-1 through NS-10 control list across families. This is the main mapping table reused for every finding.
   2. **Well-Architected Framework service guide**: search `well-architected security <service>`. Pick the most relevant `well-architected/service-guides/` result and fetch the full page via `microsoft_docs_fetch`. Extract the Security checklist, network-relevant recommendations, and tradeoffs call-outs from the fetched content, not from the search excerpt.
3. Then fetch Tier 2 supplements:
   - **Per-service reference docs**: when the Well-Architected Framework service guide does not cover a feature the IaC uses. Use `<service> <feature search term>`, then `microsoft_docs_fetch` on the best result.
4. **Fetch full page.** Every URL the skill will cite, gather data from, or use to draft a recommendation must come from a `microsoft_docs_fetch` call on that URL during this review. Do not paraphrase a search snippet, do not cite a URL whose body you have not retrieved, and do not assume the snippet includes the page's retirement banner or callouts. If a fetch fails, retry; if it keeps failing, treat the family as ungrounded per [When grounding fails](#when-grounding-fails).
5. **Scan every fetched page for retirement signals** per [deprecations.md](./deprecations.md). When a feature is flagged deprecated, retiring, in maintenance mode, or superseded, fetch the replacement's page now and use the replacement in any later recommendation. Record the deprecation in the scratch file's `## Deprecations encountered` section.
6. **Map every finding to an MCSB control.** When writing the finding (SKILL.md step 9), the References field must include both the MCSB control ID and at least one Tier 1 URL. If no MCSB control fits, re-check that the finding is in scope for this skill.

## Citation format

Applies to every URL written into the report.

- **Every URL is a markdown link `[Descriptive title](URL)`.** The display text is a human-readable title of the destination page or section. Never write bare URLs. Never use the URL itself as the display text.
- MCSB control ID is required when a matching control exists in a finding's references. Format: `MCSB control \`NS-#\`: [control title](<deep-link URL>)`.
- At least one Tier 1 citation is required on every finding.
- Use deep links to article when the article supports it (`#security`, `#network-security`, `#ns-2-...`).
- Tier 2 URLs are optional and are always listed after the Tier 1 entries.

## When grounding fails

- **MCP not configured:** Stop and tell the user. Findings without Learn grounding are not emitted by this skill.
- **No relevant search result for a component family:** Broaden the query. Do not fall back to excluded sources. If still nothing relevant, list that component family in the report's "Open questions" section with the note "couldn't locate authoritative Learn guidance; recommendations for this component withheld."
- **No MCSB control fits the finding:** This is a strong signal the finding is out of scope (IAM, secrets hygiene, encryption-at-rest, app-layer authentication).
- **Learn content contradicts a hardcoded skill rule:** Learn wins.
- **Two Tier 1 sources conflict:** prefer the Well-Architected Framework service guide over the MCSB control text when the disagreement is about a specific service feature. MCSB wins on control-family naming. Note the conflict in the issue text so the reader can investigate.
