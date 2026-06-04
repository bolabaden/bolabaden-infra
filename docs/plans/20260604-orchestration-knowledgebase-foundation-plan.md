# Orchestration Knowledgebase Foundation Plan

## Summary

Build a durable knowledgebase section that explains bolabaden's orchestration direction in one coherent narrative: the current Compose-first, no-heavy-orchestrator operating model; the near-term Constellation failover and coordination layer; and the longer-term CUE abstraction path that borrows selected ideas from Swarm/Mirantis and Kubernetes without adopting their control planes wholesale.

The output of this plan is not a new scheduler. It is a docs-and-navigation foundation that makes the repo's orchestration story understandable, searchable, and internally consistent for operators and contributors.

---

## Problem Frame

The repository already contains the ingredients of the orchestration story, but they are split across strategy docs, research notes, infra implementation docs, and experimental blueprint material:

- `README.md` and `STRATEGY.md` clearly reject Kubernetes and Swarm as the primary operating model.
- `docs/INFRASTRUCTURE_MASTER_PLAN.md` and `docs/brainstorms/20260604-failover-agent-exploration.md` define the near-term service-registry and failover direction.
- `knowledgebase/UNIFIED_ORCHESTRATION_BLUEPRINT.md`, `knowledgebase/CUE_SPEC_EXTENSIONS.md`, and `knowledgebase/CUE_BOOTSTRAP_PROTOCOL.md` describe a more ambitious abstraction layer.
- `infra/` already contains Constellation building blocks (`gossip`, `raft`, `failover`, `traefik`) but some docs still describe parts of the execution path as simulated.

Without a curated knowledgebase path, readers have to infer the intended model themselves and may come away with contradictory conclusions: "manual Compose forever," "OpenSVC as the answer," or "we are secretly rebuilding Kubernetes." The plan should make the actual direction explicit and document the boundaries honestly.

---

## Scope Boundaries

### In scope

- Inventory and consolidate the repo's orchestration source set into a single knowledgebase path.
- Explain how bolabaden maps and differentiates:
  - Docker Compose
  - Docker Swarm / Mirantis-style orchestration concepts
  - Kubernetes-style orchestration concepts
  - bolabaden's Constellation / CUE direction
- Publish durable knowledgebase pages under `knowledgebase/` and wire them into `mkdocs.yml`.
- Update landing/navigation surfaces so operators can find the new material from the docs home page.
- Capture current-state vs near-term vs future-state maturity so the docs do not overclaim what is already implemented.

### Out of scope

- Implementing new failover, lease, or migration behavior in `infra/`.
- Replacing the existing infrastructure model with Kubernetes, Swarm, or another orchestrator.
- Exhaustively documenting every infra component; this plan is about the orchestration narrative and its primary supporting concepts.

### Deferred to Follow-Up Work

- Deep, service-by-service operator runbooks for every failover scenario.
- External comparative research beyond the repo's existing materials, unless later docs work needs it.
- Refactoring existing infra docs whose only problem is writing quality rather than orchestration ambiguity.

---

## Requirements

- R1: The knowledgebase must state the canonical orchestration direction in language consistent with `STRATEGY.md`, `README.md`, and `docs/INFRASTRUCTURE_MASTER_PLAN.md`.
- R2: The docs must clearly distinguish bolabaden's no-heavy-orchestrator stance from both manual-only Compose and full Kubernetes/Swarm control-plane designs.
- R3: The docs must map familiar orchestration concepts (service identity, health, failover, placement, desired state, control plane, service registry) to bolabaden's current and planned equivalents.
- R4: The docs must preserve current-state honesty by separating implemented behavior in `infra/` from blueprint/future-state material.
- R5: The new material must live in `knowledgebase/` and be discoverable from `mkdocs.yml` navigation and the docs landing page.
- R6: The docs must point readers to the most important supporting source documents and implementation surfaces.
- R7: The docs changes must validate cleanly with the existing MkDocs and compose-based docs workflow.

---

## Key Technical Decisions

- K1: Use a **three-layer narrative** throughout the knowledgebase:
  - **Current state:** Compose-first, no central orchestrator, any-node ingress, Git-centered coordination.
  - **Near-term control layer:** `services.yaml` concepts, failover agent, gossip/Raft coordination, lease-backed anti-split-brain behavior.
  - **Future abstraction:** CUE / Constellation Unified Engine as the higher-level portable interface.
  - **Why:** This matches the strongest repo evidence and resolves the current "manual Compose vs hidden orchestrator" ambiguity.

- K2: Treat **`services.yaml` as the conceptual bridge**, not the Go `infra/config/service_registry.go` type.
  - **Why:** The repo uses "service registry" for two different ideas; the knowledgebase must avoid conflating the internal provider registry with the distributed placement/routing registry described in strategy and failover docs.

- K3: Publish the work as a **knowledgebase section**, not a plan-only artifact.
  - **Why:** `docs/plans/` is excluded from the published site; the durable reader-facing outcome must live in `knowledgebase/` and then be linked from MkDocs navigation.

- K4: Make **maturity and boundaries explicit** anywhere the docs mention Constellation automation.
  - **Why:** Some implementation surfaces exist in `infra/`, but `infra/docs/CONSTELLATION_INTEGRATION.md` still describes migration execution as simulated. The docs should describe direction without overstating readiness.

- K5: Anchor the comparison around **concept translation**, not feature parity.
  - **Why:** The point is to help operators understand how bolabaden borrows ideas from Swarm/Mirantis and Kubernetes while keeping a different operational philosophy, not to claim one-to-one equivalence.

---

## Output Structure

```text
knowledgebase/
└── orchestration/
    ├── README.md                         # Landing page for the orchestration section
    ├── orchestration-model.md            # Canonical current-state / near-term / future-state narrative
    ├── concept-mapping.md                # Compose vs Swarm/Mirantis vs Kubernetes vs bolabaden mapping
    └── constellation-control-layer.md    # Service registry, leases, failover agent, peer pickup, CUE bridge
```

The exact filenames may shift during implementation, but the final shape should include one section landing page plus a small set of focused concept pages rather than one oversized omnibus document.

---

## Implementation Units

### U1. Establish the orchestration source set and information architecture

**Goal:** Define the canonical set of source documents and the target information architecture for the orchestration knowledgebase section.

**Requirements:** R1, R5, R6

**Dependencies:** None

**Files:**
- `knowledgebase/`
- `mkdocs.yml`
- `docs/index.md`
- `README.md`
- `STRATEGY.md`
- `docs/INFRASTRUCTURE_MASTER_PLAN.md`
- `docs/brainstorms/20260604-failover-agent-exploration.md`
- `knowledgebase/UNIFIED_ORCHESTRATION_BLUEPRINT.md`
- `knowledgebase/CUE_SPEC_EXTENSIONS.md`
- `knowledgebase/CUE_BOOTSTRAP_PROTOCOL.md`

**Approach:**
- Build a source inventory that separates authoritative direction docs from reference/alternative material.
- Decide the section shape: landing page, model page, concept-mapping page, and Constellation control-layer page.
- Reserve room for cross-links to supporting implementation and research docs instead of duplicating all of their content.

**Patterns to follow:**
- `docs/index.md` for quick-navigation and status-table patterns.
- `docs/INFRASTRUCTURE_MASTER_PLAN.md` for canonical architecture terminology.
- `knowledgebase/UNIFIED_ORCHESTRATION_BLUEPRINT.md` for future-state abstraction vocabulary.

**Test scenarios:**
- Happy path: The planned section structure covers the current operating model, near-term control layer, and future-state abstraction without leaving a major source document orphaned.
- Edge case: Alternative/reference material such as OpenSVC and orchestration research remains linked as context, not elevated to the primary direction.
- Verification case: A reviewer can point from each new page outline back to at least one authoritative source document.

**Verification:**
- The implementation has a clear source-of-truth list and a stable section outline before page authoring starts.

### U2. Author the canonical orchestration model narrative

**Goal:** Create the primary knowledgebase page that explains what bolabaden is doing, what it is not doing, and how the three-layer model fits together.

**Requirements:** R1, R2, R4, R6

**Dependencies:** U1

**Files:**
- `knowledgebase/orchestration/README.md`
- `knowledgebase/orchestration/orchestration-model.md`

**Approach:**
- Write a concise landing page that routes readers to the right subtopics.
- Write a canonical model page that:
  - states the no-heavy-orchestrator boundary,
  - explains the current Compose-first topology,
  - introduces the Constellation failover/control-layer direction,
  - positions CUE as the future abstraction layer rather than a claim of present-day parity.
- Keep "implemented today" and "planned next" visibly separate.

**Patterns to follow:**
- `docs/index.md` for landing-page structure.
- `README.md` and `STRATEGY.md` for the repo's current-state framing.

**Test scenarios:**
- Happy path: A new contributor can read the model page and correctly explain why the repo is neither "just manual Compose" nor "Kubernetes in disguise."
- Edge case: A reader looking specifically for Swarm/Mirantis/Kubernetes comparisons can find the mapping page from the landing page without searching the whole site.
- Error path: The page does not describe simulated or incomplete Constellation behavior as fully productionized.

**Verification:**
- The landing page and model page use consistent terminology and route readers to supporting docs without ambiguity.

### U3. Document concept mapping across Compose, Swarm/Mirantis, Kubernetes, and bolabaden

**Goal:** Publish the translation layer that helps operators understand equivalent concepts without implying one-to-one platform parity.

**Requirements:** R2, R3, R6

**Dependencies:** U1, U2

**Files:**
- `knowledgebase/orchestration/concept-mapping.md`

**Approach:**
- Organize the page around a comparison matrix or grouped sections for:
  - placement / scheduling
  - service identity
  - routing and ingress
  - health and failover
  - control plane / desired state
  - secrets and storage constraints
- For each concept, explain the bolabaden equivalent (or intentional non-equivalent) using current and planned constructs such as Traefik routing, `services.yaml`, gossip state, leases, and peer pickup.
- Treat Mirantis in the Swarm-family context unless the repo has a distinct Mirantis-specific direction to document.

**Patterns to follow:**
- `docs/orchestration_research_2026.md` for comparative framing.
- `knowledgebase/CUE_SPEC_EXTENSIONS.md` for the future abstraction surface.

**Test scenarios:**
- Happy path: A reader familiar with Kubernetes can identify the bolabaden equivalent or intentional omission for service registry, failover coordination, and desired-state behavior.
- Edge case: Concepts with no exact equivalent are called out explicitly rather than forced into misleading parity language.
- Error path: The comparison does not suggest that bolabaden currently has a full scheduler, controller-manager, or declarative reconciliation loop when it does not.

**Verification:**
- The comparison page reduces confusion instead of introducing new overloaded terms.

### U4. Document the Constellation control layer and maturity boundaries

**Goal:** Explain how `infra/` fits into the orchestration story today and where the failover/control-layer work is still emerging.

**Requirements:** R3, R4, R6

**Dependencies:** U2, U3

**Files:**
- `knowledgebase/orchestration/constellation-control-layer.md`
- `infra/cmd/agent/main.go`
- `infra/cluster/gossip/state.go`
- `infra/cluster/raft/leases.go`
- `infra/failover/migration.go`
- `infra/docs/CONSTELLATION_INTEGRATION.md`

**Approach:**
- Document the role of gossip, leases, Traefik provider generation, and migration/failover logic in operator-facing terms.
- Call out the difference between:
  - implemented cluster primitives,
  - planned service-registry and peer-pickup behavior,
  - future CUE-driven abstraction.
- Include the `services.yaml` bridge concept and explicitly warn against confusing it with the internal Go service registry type.

**Patterns to follow:**
- `infra/docs/ARCHITECTURE.md` and `infra/docs/COMPONENTS.md` for component descriptions.
- `docs/brainstorms/20260604-failover-agent-exploration.md` for peer-pickup and split-brain problem framing.

**Test scenarios:**
- Happy path: A reader can trace how a service failure would be detected, coordinated, and routed around in the intended architecture.
- Edge case: Statefulness, secret distribution, and split-brain constraints are presented as design boundaries where the docs should remain cautious.
- Error path: The docs do not claim that all migration execution paths are already live if the linked infra docs still mark parts as simulated.

**Verification:**
- The Constellation page accurately reflects the code/docs maturity line and links to deeper implementation detail where needed.

### U5. Wire the section into MkDocs navigation and validate the docs build

**Goal:** Make the new orchestration material discoverable and keep the docs site healthy after the additions.

**Requirements:** R5, R7

**Dependencies:** U2, U3, U4

**Files:**
- `mkdocs.yml`
- `docs/index.md`
- `knowledgebase/orchestration/README.md`
- `knowledgebase/orchestration/orchestration-model.md`
- `knowledgebase/orchestration/concept-mapping.md`
- `knowledgebase/orchestration/constellation-control-layer.md`

**Approach:**
- Add the new pages to the most appropriate section of `mkdocs.yml` with a coherent nav label set.
- Update the docs landing page so the orchestration section is easy to find from the home page.
- Validate links and ensure the new section does not break strict site generation.

**Execution note:** Start with failing navigation/build validation if the new files are introduced incrementally; finish with a strict docs build once the nav is complete.

**Patterns to follow:**
- `mkdocs.yml` existing explicit-nav structure.
- `docs/index.md` quick-navigation style.

**Test scenarios:**
- Happy path: The new orchestration pages appear in the rendered site nav and are reachable from the docs home page.
- Edge case: Repo-relative links between the new pages and existing infra/docs content resolve correctly in the built site.
- Error path: Strict build catches missing nav targets, broken internal links, or misplaced docs paths before the work is considered complete.

**Verification:**
- The docs site builds cleanly with the new pages included, and the new section is discoverable from both nav and the landing page.

---

## Risks & Dependencies

### Risks

- The repo currently carries multiple orchestration narratives (README, master plan, blueprint, OpenSVC research); poor synthesis could preserve confusion instead of reducing it.
- The "service registry" term is overloaded and could mislead readers without careful distinction.
- The docs may accidentally overstate implementation maturity if blueprint and code-level material are merged without clear boundaries.
- MkDocs nav changes can fail quietly if page paths or relative links drift.

### Dependencies

- The authoritative direction docs listed in U1 remain the baseline sources.
- `mkdocs.yml` continues to publish from `knowledgebase/`.
- The docs validation path remains the existing strict MkDocs build and compose-backed docs workflow.

---

## Sources & Research

- `STRATEGY.md`
- `README.md`
- `docs/INFRASTRUCTURE_MASTER_PLAN.md`
- `plan-infrastructure-unification.md`
- `docs/brainstorms/20260604-failover-agent-exploration.md`
- `docs/orchestration_research_2026.md`
- `knowledgebase/UNIFIED_ORCHESTRATION_BLUEPRINT.md`
- `knowledgebase/CUE_SPEC_EXTENSIONS.md`
- `knowledgebase/CUE_BOOTSTRAP_PROTOCOL.md`
- `infra/cmd/agent/main.go`
- `infra/cluster/gossip/state.go`
- `infra/cluster/raft/leases.go`
- `infra/failover/migration.go`
- `infra/docs/CONSTELLATION_INTEGRATION.md`
- `mkdocs.yml`
- `docs/index.md`
