# Sprint 003 — Ingestion automation

- id: 3
- intent: Uploading a video to S3 is the only manual step left — the rest
  (deciding there's work to do, starting the GPU instance) happens on its
  own within the hour.
- affected: `lambda/trigger/handler.py`, `infra/lambda.tf`, `infra/iam.tf`
  (trigger Lambda role), `infra/eventbridge.tf` (hourly schedule)
- prereqs: 2
- playbook: feature
- risk: medium (the main risk is the idle-cost gate silently failing and
  starting EC2 every hour regardless)

## Tasks

1. `lambda/trigger/handler.py`: list `incoming/<camera_id>/` objects, list
   `processed/<camera_id>/` objects, diff them; if anything is pending, call
   `ec2:StartInstances`; otherwise exit without touching EC2.
2. Terraform: package + deploy the Lambda (zip, no container needed),
   scoped IAM role (`s3:ListBucket`/`GetObject` on `incoming/*`,
   `ec2:StartInstances` scoped to the one instance ARN), EventBridge
   Scheduler rule (hourly) invoking it, with an IAM role scoped to that one
   function ARN.

## Definition of Done

- [ ] Manually invoking the trigger Lambda with a video sitting in
      `incoming/` and nothing in `processed/` for it: EC2 transitions
      `stopped` → `running`, and by the end of Sprint 2's flow, back to
      `stopped`, with the detection landing in DynamoDB.
- [ ] Manually invoking the trigger Lambda with `incoming/` fully mirrored
      in `processed/` (nothing pending): EC2 stays `stopped` — confirmed via
      console, not just "the Lambda didn't error."
- [ ] The hourly EventBridge schedule exists and its target is the trigger
      Lambda (`terraform apply` output / console check — not required to
      wait a full hour to prove it fires, this is a config-correctness
      check).
- [ ] IAM role for the Lambda has no `*` resource on `ec2:StartInstances` or
      the S3 actions.
