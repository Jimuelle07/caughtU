# Sprints

The caughtU build is cut into 5 sprints, each a vertical increment on the
architecture in `../system-design.md`. Format follows the Monozukuri
`greenfield` phase-plan template
(`.agents/skills/monozukuri-core/references/templates/blueprint/phase-plan.md`):
each sprint states its `intent`, the areas it touches, its prerequisites, and
a Definition of Done, per
`.agents/skills/monozukuri-core/references/definition-of-done.md`'s
`greenfield` checklist ("each completed phase passed its own playbook's DoD").

| Sprint | Name | Intent |
|---|---|---|
| [001](sprint-001.md) | Core detection slice | Prove YOLO detection → DynamoDB + S3 works end-to-end, run manually |
| [002](sprint-002.md) | Automated GPU compute | EC2 instance boots, runs inference, self-stops — no manual babysitting |
| [003](sprint-003.md) | Ingestion automation | Uploading a video eventually triggers the whole pipeline unattended |
| [004](sprint-004.md) | Reporting | 8-hourly CSV email of all detections |
| [005](sprint-005.md) | Hardening & polish | Cost/IAM tightening, lifecycle rules, full end-to-end verification |

## Phase order rationale

Sprint 1 is the vertical slice: it proves the actual hard part (does YOLO +
DynamoDB + S3 storage work at all) before any scheduling/orchestration is
built around it — no point automating a pipeline that doesn't work manually
first. Sprints 2–3 build the automation the core slice is missing (compute
that turns itself on/off, ingestion that doesn't need a human to start it).
Sprint 4 is fully independent of 2–3 (it only reads DynamoDB) and could be
built in parallel, but is sequenced after so there's real detection data to
report on when testing it. Sprint 5 is cleanup that only makes sense once the
system exists to harden.
