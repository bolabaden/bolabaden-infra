# AIOStreams v2.30 LFG Rerun Plan (2026-06-03)

## Goal

Re-run the migration closure gates in strict order and publish updated evidence that the v2.30 migration remains complete and stable.

## Ordered Steps

1. Baseline snapshot

* Capture health for aiostreams/traefik/stremio/stremthru.
* Record UTC rerun start timestamp (`date -u +%Y-%m-%dT%H:%M:%SZ`) and use it as the lower bound for all evidence/log collection.
* Capture aiostreams logs bounded to this rerun window (`docker logs --since <rerun-start-utc> aiostreams`).

2. Auth and dashboard gate

* Confirm dashboard settings page is reachable in authenticated state.
* Confirm settings actions menu and import environment workflow is reachable.

3. Runtime and manifest gate

* Verify addon manifest endpoint returns HTTP 200.
* Verify addon manifest fields match expected values:
	* `id = aiostreams.bolabaden.org`
	* `name = BadenAIO`
	* `version` starts with `2.30.`

4. Persistence and behavior gate

* Verify migrated v2.30 env keys are present in running container.
* Verify deprecated keys are absent.
* Verify persisted DB interval values remain in corrected second units.

5. Restart stability gate

* Restart aiostreams service.
* Re-check health and addon manifest endpoint.
* Re-check authenticated dashboard/settings access after restart.

6. Documentation closure

* Append rerun evidence and acceptance outcome to migration audit doc.

## Acceptance Criteria

* Services healthy before and after restart.
* Dashboard settings remains reachable in authenticated context before and after restart.
* https://aiostreams.bolabaden.org/stremio/manifest.json returns HTTP 200 with expected id/name/version.
* v2.30 keys present and deprecated keys absent in runtime env.
* Persisted DB anime refresh intervals remain in second units: 86400/604800.

## Deliverables

* Plan file: docs/plans/20260603-aiostreams-v230-lfg-rerun-plan.md
* Updated audit file: docs/aiostreams-v230-migration-audit-2026-06-03.md (rerun section)
