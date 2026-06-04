***

mode: agent
model: Claude Sonnet 4
----------------------

<!-- markdownlint-disable-file -->

# Implementation Prompt: AIOStreams v2.30 LFG Closure Pipeline Now

## Implementation Instructions

### Step 1: Create Changes Tracking File

You WILL create `20260603-aiostreams-v230-lfg-closure-pipeline-changes.md` in #file:../changes/ if it does not exist.

### Step 2: Execute Implementation

You WILL follow #file:../../.github/instructions/task-implementation.instructions.md.
You WILL systematically implement #file:../plans/20260603-aiostreams-v230-lfg-closure-pipeline-plan.instructions.md task-by-task.
You WILL update closure evidence in:

* docs/aiostreams-v230-migration-audit-2026-06-03.md
* docs/plans/20260603-aiostreams-v230-lfg-closure-pipeline-now-plan.md

You WILL ensure the run explicitly covers:

* Browser gate for dashboard auth.
* Dashboard import and immediate persistence.
* Post-restart persistence checks.
* Runtime/log regression checks.
* Docs correctness and review closure.
* Commit/push/PR/CI delivery gate handling.

**CRITICAL**: If ${input:phaseStop:true} is true, you WILL stop after each Phase for user review.
**CRITICAL**: If ${input:taskStop:false} is true, you WILL stop after each Task for user review.

### Step 3: Cleanup

When ALL Phases are checked off (`[x]`) and completed you WILL do the following:

1. You WILL provide a markdown style link and a summary of all changes from #file:../changes/20260603-aiostreams-v230-lfg-closure-pipeline-changes.md to the user.
2. You WILL provide markdown style links to:

* .copilot-tracking/plans/20260603-aiostreams-v230-lfg-closure-pipeline-plan.instructions.md
* .copilot-tracking/details/20260603-aiostreams-v230-lfg-closure-pipeline-details.md
* .copilot-tracking/research/20260603-aiostreams-v230-lfg-rerun-research.md

3. **MANDATORY**: You WILL attempt to delete .copilot-tracking/prompts/implement-aiostreams-v230-lfg-closure-pipeline.prompt.md.

## Success Criteria

* \[ ] Changes tracking file created
* \[ ] All plan items implemented with working validation evidence
* \[ ] All detailed specifications satisfied
* \[ ] Project conventions followed
* \[ ] Changes file updated continuously
