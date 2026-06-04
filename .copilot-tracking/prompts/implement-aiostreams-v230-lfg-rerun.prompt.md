---
mode: agent
model: Claude Sonnet 4
---

<!-- markdownlint-disable-file -->

# Implementation Prompt: AIOStreams v2.30 LFG Rerun Validation (Post-Recreate)

## Task Overview

Execute a concise post-recreate rerun that validates AIOStreams v2.30 migration gates and publishes closure evidence.

## Implementation Instructions

### Step 1: Create Changes Tracking File

You WILL create `20260603-aiostreams-v230-lfg-rerun-changes.md` in #file:../changes/ if it does not exist.

### Step 2: Execute Implementation

You WILL follow #file:../plans/20260603-aiostreams-v230-lfg-rerun-plan.instructions.md task-by-task.
You WILL execute gates in strict order:
1. Forced-recreate baseline
2. Dashboard auth/import checks
3. Runtime env key + manifest/runtime + DB persistence checks
4. Post-restart stability checks
5. Concise documentation closure

**CRITICAL**: If ${input:phaseStop:true} is true, you WILL stop after each Phase for user review.
**CRITICAL**: If ${input:taskStop:false} is true, you WILL stop after each Task for user review.

### Step 3: Cleanup

When all phases are checked off (`[x]`) and completed:

1. You WILL summarize changes from #file:../changes/20260603-aiostreams-v230-lfg-rerun-changes.md.
2. You WILL provide links to plan, details, and research files.
3. You WILL attempt to delete .copilot-tracking/prompts/implement-aiostreams-v230-lfg-rerun.prompt.md.

## Success Criteria

- [ ] Forced recreate context captured
- [ ] Dashboard auth/import validated
- [ ] Runtime env migration keys validated
- [ ] DB persistence and post-restart stability validated
- [ ] Concise closure summary produced
