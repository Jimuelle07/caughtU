# System Design — caughtU

## Overview

Two independent EventBridge-driven paths sharing one S3 bucket and one
DynamoDB table. All infra is provisioned via Terraform, in the account's
default VPC, region `us-east-1`, all resources named with a `caughtu-` prefix.

```
                     ┌────────────────────┐
  upload .mp4  ───►  │  S3 incoming/      │
                     └─────────┬──────────┘
                               │  (hourly)
                     ┌─────────▼──────────┐
                     │  trigger Lambda    │  any pending video?
                     └─────────┬──────────┘
                       no ──── │ ──── yes
                     (exit, no cost)   │
                               ▼
                     ┌────────────────────┐   run_batch.py:
                     │  EC2 g4dn.xlarge   │──►  YOLOv8 inference
                     │  (stopped→running) │     per-frame detection
                     └─────────┬──────────┘
                               │
                 ┌─────────────┼──────────────┐
                 ▼             ▼              ▼
          DynamoDB item   S3 crops/     S3 processed/
          (per detection)  (snapshot)    (mark done)
                               │
                    instance self-stops (OS shutdown →
                    InstanceInitiatedShutdownBehavior=stop)

  ─────────────────────────────────────────────────────────

                     ┌────────────────────┐
                     │  EventBridge (8h)  │
                     └─────────┬──────────┘
                               ▼
                     ┌────────────────────┐
                     │  report Lambda     │  query GSI: last 8h
                     └─────────┬──────────┘
                               ▼
                     S3 reports/*.csv  +  SES email w/ CSV attachment
```

## Path A — batch inference (hourly check)

1. User manually uploads a video to
   `s3://caughtu-media/incoming/<camera_id>/<file>.mp4`.
2. EventBridge Scheduler (hourly cron) invokes the **trigger Lambda**.
3. Trigger Lambda lists `incoming/` for anything not yet mirrored in
   `processed/`. Nothing pending → exit, no EC2 start, no cost. Otherwise it
   calls `ec2:StartInstances` on the pre-created (stopped) instance.
4. The instance boots from AWS's Deep Learning AMI (GPU PyTorch, Ubuntu
   22.04) so CUDA/PyTorch are already present — `scripts/bootstrap_ec2.sh`
   (user-data, runs once at first launch) only pulls `inference/` code from
   `s3://caughtu-media/code/`, installs `requirements.txt`, and installs a
   `caughtu-inference.service` systemd unit (`Type=oneshot`, enabled at
   boot — runs on every subsequent start, not just the first). On boot, that
   unit runs `inference/run_batch.py`:
   - downloads each pending video,
   - runs YOLOv8 (ultralytics) at a sampled fps,
   - writes one DynamoDB item per detection (`helmet` / `no_helmet`),
   - uploads the cropped rider snapshot to `crops/`,
   - moves the source video to `processed/` (the "already done" marker).
5. The script exits and the OS shuts down; because the instance's
   `InstanceInitiatedShutdownBehavior` is set to `stop` (not `terminate`),
   this maps to an EC2 **Stop** — billing stops without the instance needing
   `ec2:StopInstances` IAM permission on itself.

## Path B — 8-hour report (fully decoupled from Path A)

1. EventBridge Scheduler (every 8h) invokes the **report Lambda**.
2. Lambda queries DynamoDB via the `report_gsi` GSI for all detections with
   `detection_ts` in the last 8 hours.
3. Lambda builds a CSV in memory, uploads it to `reports/` (audit trail), and
   sends it via SES `SendRawEmail` as an attachment to
   `jimuellepatron10@gmail.com`.

No EC2 involvement in Path B.

## DynamoDB — table `caughtu-detections`

| Field | Type | Notes |
|---|---|---|
| `camera_id` | string (PK) | one camera for now, but keeps multi-camera queries cheap later |
| `detection_ts` | string (SK) | ISO-8601, sortable |
| `detection_id` | string | uuid, also the crop filename |
| `label` | string | `helmet` \| `no_helmet` |
| `crop_s3_key` | string | link to the snapshot in S3 |
| `source_video_key` | string | which uploaded video this came from |
| `confidence` | number | YOLO confidence score |

GSI `report_gsi`: PK `report_bucket` (constant `"ALL"` for now), SK
`detection_ts` — lets the report Lambda `Query` "everything in the last 8h"
instead of a full table scan.

> `ponytail:` a single-value GSI partition key is a deliberate corner cut —
> fine at hobby-project volume. Upgrade to a per-day bucket string if this
> ever needs to handle real traffic (avoids one hot partition).

Billing mode: `PAY_PER_REQUEST` (on-demand).

## S3 — bucket `caughtu-media-<suffix>`

| Prefix | Contents |
|---|---|
| `incoming/<camera_id>/` | uploaded, unprocessed videos |
| `processed/<camera_id>/` | videos already run through inference |
| `crops/<camera_id>/<detection_id>.jpg` | cropped rider snapshots |
| `reports/<window_start>_<window_end>.csv` | generated reports (audit trail) |
| `models/` | YOLO `.pt` weights, downloaded once at first EC2 boot, cached on EBS |
| `code/` | `inference/*.py` + `requirements.txt`, synced here by `terraform apply`; the EC2 instance pulls from here at every boot instead of using a CI/CD pipeline |

Lifecycle rule expires `processed/*` and `crops/*` after ~90 days to bound
storage cost.

## IAM (scoped by resource/prefix, no `*`)

- **EC2 instance role**: S3 read `incoming/*`, `models/*`, `code/*`;
  read/write `processed/*`, `crops/*`; DynamoDB `PutItem`/`BatchWriteItem` on
  the detections table only.
- **Trigger Lambda role**: S3 `ListBucket`/`GetObject` on `incoming/*`;
  `ec2:StartInstances` scoped to the one instance ARN; CloudWatch Logs.
- **Report Lambda role**: DynamoDB `Query` on the table + GSI; S3
  `PutObject` on `reports/*`; SES `SendRawEmail` scoped to the verified
  identity; CloudWatch Logs.
- **EventBridge Scheduler role(s)**: `lambda:InvokeFunction` scoped to each
  Lambda's ARN.

## SES

Both the sender identity and the recipient (`jimuellepatron10@gmail.com`)
must be manually verified (click the AWS confirmation email) after
`terraform apply` — SES sandbox mode requires this on both ends and cannot be
automated by Terraform. No production-access request needed for a single
fixed recipient.

## Model

Pretrained YOLOv8 helmet-detection weights, e.g.
[Roboflow Universe — Bike Helmet Detection](https://universe.roboflow.com/object-detection-using-yolov8/bike-helmet-detection-2vdjo-semr0),
exported as a `.pt` file and placed under `s3://caughtu-media/models/`. Treated
as a swappable config value, not hardcoded.

## Repo layout

```
caughtU/
  infra/          Terraform: S3, DynamoDB, EC2, IAM, Lambda, EventBridge, SES
  inference/       Python app that runs on the EC2 instance (ultralytics YOLO)
  lambda/
    trigger/        checks incoming/, starts EC2 if there's pending work
    report/          queries DynamoDB, builds CSV, sends via SES
  scripts/           one-time EC2 bootstrap (installs deps, sets up systemd)
```

No multi-environment split, no CI/CD, no containerized Lambdas — plain zip
deploys (via the `hashicorp/archive` Terraform provider) are enough since
Lambda dependencies are just `boto3` (already in the runtime). The EC2
instance has no equivalent artifact store, so it pulls `inference/*.py`
straight from `s3://caughtu-media/code/` at boot instead.

## Cost drivers

GPU EC2 time is the only real cost, bounded by: stopped by default, the
trigger Lambda skips starting it when nothing is pending, and it self-stops
immediately after the batch finishes. S3, DynamoDB (on-demand), Lambda,
EventBridge, and SES are effectively free at this volume.

## Process note

This project follows the Monozukuri methodology already vendored in
`.agents/skills/` (see `monozukuri-router`), applied inline since it isn't
wired up as a Claude Code plugin. Classified as `greenfield`: sequence is
`nemawashi → monozukuri-blueprint` (gated phases) → per phase
`kanso → kata → poka-yoke → kodawari → andon → shukka → hansei`.

## Verification plan

1. `terraform apply` — confirm bucket, table, stopped EC2 instance, both
   Lambdas, both schedules, and SES identities exist.
2. Click both SES verification emails (sender + recipient).
3. Upload one sample video with both a helmeted and unhelmeted rider to
   `incoming/cam1/test1.mp4`.
4. Manually invoke the trigger Lambda — confirm EC2 goes stopped → running.
5. Watch CloudWatch Logs while `run_batch.py` runs; confirm the instance
   returns to `stopped` on its own afterward.
6. Check DynamoDB for new items with correct `label`, `camera_id`,
   `detection_ts`, `crop_s3_key`.
7. Check `crops/cam1/` — open a crop, confirm it's an actual rider image.
8. Confirm the video moved to `processed/cam1/` and is gone from `incoming/`.
9. Manually invoke the report Lambda — confirm a CSV lands in `reports/` and
   matches DynamoDB for the window.
10. Confirm the email arrives with a CSV attachment that opens cleanly, both
    labels represented.
11. Re-run the trigger Lambda with nothing new in `incoming/` — confirm it
    does **not** start EC2 (proves the idle-cost gate works).
