# Sprint 005 — Hardening & polish

- id: 5
- intent: The full pipeline (upload → detect → store → report) runs
  unattended end-to-end, costs stay near zero when idle, and the system is
  documented well enough to hand off or resume after a break.
- affected: `infra/s3.tf` (lifecycle rules), `infra/iam.tf` (least-privilege
  review), `README.md`, `docs/system-design.md`, `docs/idea.md`
- prereqs: 1, 2, 3, 4
- playbook: refactor (no new behavior, tightening what exists) + release
- risk: low

## Tasks

1. S3 lifecycle rules: expire `processed/*` and `crops/*` after ~90 days.
2. IAM audit: re-check every role against `system-design.md` § IAM — no `*`
   resource anywhere, no unused permissions left over from earlier sprints.
3. Optional: a CloudWatch alarm/billing guardrail that flags (not
   necessarily force-stops) the EC2 instance if it's been `running` longer
   than expected — only add if Sprint 2 testing showed a real risk of a
   stuck run, per the "open assumptions" note in `system-design.md`.
4. Run the full 11-step verification plan in `system-design.md` § Verification
   plan end to end, in order, from a cold state (bucket has whatever real
   test data accumulated across sprints — no need to reset it).
5. Hansei: update `docs/idea.md` / `docs/system-design.md` with anything
   that changed from the original plan during implementation (model swapped,
   schedule cadence changed, etc.) so the docs stay accurate.

## Definition of Done

- [ ] All 11 verification-plan steps pass in one continuous run.
- [ ] Lifecycle rules confirmed in the S3 console (or `terraform plan`
      shows no drift).
- [ ] IAM policies reviewed line-by-line against `system-design.md` — no
      `*` resources remain.
- [ ] Docs match what was actually built (any deviations during Sprints
      1–4 reflected back into `idea.md`/`system-design.md`).
- [ ] Evidence ledger: this sprint's DoD items are traceable to something
      concrete (a console screenshot, a `terraform plan` output, the actual
      email received) — not just "looks right."
