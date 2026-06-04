# Plan: Stremio HLSv2 Middleware Hardening + Browser E2E Validation

## Goal
Make Stremio HLSv2 playback robust for the current failing classes (notably `stream ended` in playlist/segment reads), validate via API-level and browser-level E2E checks, and keep compose/config files unchanged.

## Constraints
- Do not modify compose/config assets for this task.
- Focus on runtime/middleware behavior in the active Stremio server path.
- Validation must include both request-path probing and browser playback checks.

## Local Hypothesis
The remaining playback failures are controlled by stream-read middleware behavior in the bundled server (`stream ended` raised from read aggregation), where transient upstream interruptions are treated as terminal errors without bounded retries.

## Disconfirming Check
After adding bounded retry handling around playlist/segment read failures, the previously failing stream classes should progress from `READ_*_FAILED` 500 responses to successful track/segment delivery for at least one previously failing source while preserving existing passing cases.

## Execution Steps
1. Confirm current baseline with a focused matrix (known pass + known fail + exact user stream).
2. Patch runtime middleware behavior in the active Stremio server bundle to add minimal, bounded retry logic for stream-ended read failures.
3. Validate immediately with the same focused matrix.
4. Run browser E2E checks using `open_browser_page` and playback-page assertions.
5. Capture results and regressions, then iterate once if needed.
6. Prepare commit/push/PR and CI follow-up per lfg pipeline requirements.

## Validation Targets
- Exact failing user stream (`elfhosted_backrooms`) reaches segment delivery.
- Previously failing MP4 class (`samplelib`/`filesamples`) improves on playlist/segment generation.
- Previously passing sources (`archive`, `blender`, `w3_hls`, `aac_m4a`) remain passing.

## Risks
- Runtime bundle patching can be brittle due to minified code structure.
- Some sources may still fail due to upstream transport behavior outside local control.
- Browser checks may require fallback to direct HLS endpoint validation if full UI playback instrumentation is blocked.

## Deliverables
- Runtime middleware patch (no compose/config changes).
- Reproducible test scripts/results for API and browser checks.
- Pushed branch updates and PR/CI status per lfg sequence.