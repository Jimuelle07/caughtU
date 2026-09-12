# Sprint 004 — Reporting

- id: 4
- intent: Every 8 hours, a CSV of all detections in that window lands in the
  inbox at jimuellepatron10@gmail.com, unattended.
- affected: `lambda/report/handler.py`, `infra/lambda.tf`, `infra/iam.tf`
  (report Lambda role), `infra/eventbridge.tf` (8h schedule), `infra/ses.tf`
- prereqs: 1 (only needs DynamoDB to have data in it — independent of
  Sprints 2–3's automation, sequenced after so there's real data to test
  against)
- playbook: feature
- risk: medium (SES sandbox verification is a manual, easy-to-forget,
  out-of-band step)

## Tasks

1. Terraform: SES email identity resources for the sender and for
   `jimuellepatron10@gmail.com`. **Manual step after apply: click both AWS
   verification emails — nothing sends until this is done.**
2. `lambda/report/handler.py`: `Query` the `report_gsi` GSI for
   `detection_ts` in the last 8 hours, build a CSV in memory (headers:
   `detection_id, camera_id, detection_ts, label, confidence, crop_s3_key`),
   upload it to `s3://caughtu-media/reports/<window_start>_<window_end>.csv`,
   send via SES `SendRawEmail` with the CSV attached.
3. Terraform: package + deploy the Lambda, scoped IAM role (DynamoDB
   `Query` on the table + GSI, S3 `PutObject` on `reports/*`, SES
   `SendRawEmail` scoped to the verified identity), EventBridge Scheduler
   rule (every 8h).

## Definition of Done

- [ ] Both SES identities show `Verified` in the console.
- [ ] Manually invoking the report Lambda (don't wait 8h) with existing
      DynamoDB data produces a CSV in `reports/` whose rows match a manual
      DynamoDB query for the same window.
- [ ] The email arrives at jimuellepatron10@gmail.com with the CSV attached
      and it opens cleanly in a spreadsheet app — correct headers, one row
      per detection, both `helmet` and `no_helmet` represented if both exist
      in the window.
- [ ] Invoking the report Lambda for a window with zero detections doesn't
      crash — it should send an email with just headers (or a "no
      detections" note), not silently fail.
- [ ] The 8h EventBridge schedule exists and targets the report Lambda.
