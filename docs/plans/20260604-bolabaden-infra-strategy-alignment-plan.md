---
title: bolabaden.org Infrastructure Strategy Alignment
type: refactor
status: completed
date: 2026-06-04
origin: STRATEGY.md
---

# bolabaden.org Infrastructure Strategy Alignment

## Summary
Update the `STRATEGY.md` file to reflect the 11 capability gaps and shift from manual to automated/self-healing infrastructure as defined in the `INFRASTRUCTURE_MASTER_PLAN.md`.

## Problem Frame
The current `STRATEGY.md` describes the infrastructure's approach and tracks at a high level that leans toward manual intervention and lightweight sync. The `INFRASTRUCTURE_MASTER_PLAN.md` has since identified concrete gaps and modules (Headscale HA, Auto-Redeploy, CI/CD unification) that represent a more mature, automated vision. Strategy and execution plans are currently drifting.

## Requirements
- R1. Update "Target problem" to emphasize the "manual synchronization" bottleneck and cross-VPS consistency.
- R2. Update "Our approach" to explicitly include "automated self-healing" and "horizontal scalability" as core commitments.
- R3. Refine "Key metrics" to include automation-specific outcomes (e.g., "automated recovery success rate").
- R4. Realign "Tracks" to map to the 11 modules in the master plan (Grouped: Automation, High Availability, Sync/State, and Observability).
- R5. Ensure all file paths and references are repo-relative and resolve correctly.

## Key Technical Decisions
- **Decision: Grouping Tracks by Theme** - The 11 modules will be grouped into 4-5 thematic tracks rather than listing 11 top-level tracks, keeping the document scan-readable.
- **Decision: Metric Evolution** - Transition metrics from "operator intervention rate" to "automated recovery success," signaling the shift toward self-healing.

## Implementation Units
### U1. Strategy Document Update
- **Goal:** Revise `STRATEGY.md` sections (Target Problem, Approach, Metrics, Tracks) to align with the Master Plan.
- **Files:** `STRATEGY.md`
- **Patterns:** Follow Rumelt's kernel (Diagnosis, Guiding Policy, Coherent Action).
- **Test Scenarios:**
  - Verify "Tracks" cover the intended 11 modules.
  - Verify "Approach" includes self-healing language.
- **Verification:** `grep` for "self-healing", "automation", and "Headscale" in the updated file.

## Sources / Research
- [docs/INFRASTRUCTURE_MASTER_PLAN.md](docs/INFRASTRUCTURE_MASTER_PLAN.md) - Primary source for capability gaps and modules.
- [README.md](README.md) - Secondary context on the "no-cluster" philosophy.
