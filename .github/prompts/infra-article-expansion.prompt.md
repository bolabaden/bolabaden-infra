# Infra Article Expansion (Reusable Prompt)

Use this prompt when working on long-form infrastructure planning or analysis documents such as `plan-infrastructure-unification.md`.

## Objective
Transform short or partial notes into a high-quality, deeply technical, readable long-form article/plan that:
- Fully expands every section and subsection.
- Rephrases vague statements into precise technical plain language.
- Preserves the author’s intent and terminology context.
- Explains what systems are doing and why failures happen.

## Core Behavior Requirements
1. Inspect the current target document first and continue from the existing structure.
2. Expand all sections, not just selected parts.
3. Do not leave shorthand terms unexplained in narrative sections.
4. Move deep tangents and term definitions into a dedicated glossary/appendix.
5. If the user requests problem-only framing, do not include remediations/fixes in the main narrative.
6. Keep all claims tied to the actual repo context and architecture patterns.

## Research and Context Gathering
Before writing, inspect relevant files in the codebase to ground terminology and examples (compose files, scripts, service registry, proxy config, app configs).

Minimum context pass:
- Read the target article/document.
- Read `docker-compose.yml` and relevant `compose/docker-compose.*.yml` files.
- Read `.github/copilot-instructions.md`.
- Read relevant app/service configs (for example, Next.js, proxy, healthchecks) when referenced in narrative.

## Writing Style Contract
- Technical plain language in the main narrative.
- No conversational shorthand assumptions.
- Explain mechanics chronologically where relevant (event ordering, lifecycle timing, request flow phases).
- Prefer clear cause-and-effect over abstract statements.
- Keep section headers stable unless restructuring improves clarity.

## Expansion Depth Expectations
For each subsection:
- Explain intent of the component/tool.
- Explain actual runtime behavior.
- Explain failure mode mechanics.
- Explain operational/human impact.
- Add cross-links to glossary terms when term depth would break flow.

## Glossary / Appendix Rules
- Add or update an appendix that defines specialized terms used in the article.
- Definitions must be precise and implementation-aware.
- Keep glossary independent and lookup-friendly.
- Do not duplicate full glossary content inside narrative sections.

## Citation and Bibliography Rules (Mandatory)
If a bibliography/addendum is included:
1. Use external primary sources whenever possible (official docs, standards, RFCs).
2. Verify links before insertion (must resolve successfully).
3. Do not invent or imply unverified references.
4. Prefer direct deep links to relevant sections, not generic homepages.
5. Keep citation descriptions mapped to the exact section they support.

Suggested reference categories:
- Official product documentation (Docker, NGINX, Next.js, SQLite, etc.)
- Standards documents (RFCs)
- Canonical methodology references when applicable

## Quality Gate (Must pass before finishing)
- Every section has been expanded.
- No unresolved shorthand remains in narrative text.
- Glossary contains all specialized concepts introduced.
- Narrative and glossary are consistent in terminology.
- Any bibliography links are verified and specific.
- Tone remains technically authoritative and readable.

## Execution Pattern
1. Review existing doc structure.
2. Gather repo context and implementation details.
3. Expand section-by-section in-place.
4. Add/refresh glossary terms.
5. Add/refresh verified bibliography (if requested or present).
6. Final consistency pass for terminology and clarity.

## Reusable Invocation Text
"Inspect and continue expanding the current infrastructure article/plan in place. Fully detail each section in technical plain language, eliminate shorthand from narrative text, move deep term definitions to a glossary/appendix, and verify all bibliography links before including them. Keep wording grounded in this repository’s actual architecture and configs."
