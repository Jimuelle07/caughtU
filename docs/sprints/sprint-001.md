# Sprint 001 — Core detection slice

- id: 1
- intent: Prove a video → YOLO detection → DynamoDB item + S3 crop actually
  works, run manually, before any scheduling/automation is built around it.
- affected: `infra/main.tf`, `infra/s3.tf`, `infra/dynamodb.tf`, `infra/iam.tf`
  (minimal), `inference/detect.py`, `inference/storage.py`,
  `inference/run_batch.py`, `inference/requirements.txt`
- prereqs: none
- playbook: feature
- risk: medium (real AWS resources, but nothing cost-bearing yet — no EC2,
  no idle compute)

## Tasks

1. Terraform: S3 bucket (`incoming/`, `processed/`, `crops/`, `models/`
   prefixes), DynamoDB table `caughtu-detections` + `report_gsi` (see
   `system-design.md`), a minimal IAM user/role for local testing.
2. Source the pretrained YOLOv8 helmet-detection weights (Roboflow Universe
   — see `system-design.md` § Model) and upload to `s3://caughtu-media/models/`.
3. `inference/detect.py` — load the weights, run inference on a local video
   file at a sampled fps, yield `(frame_ts, label, bbox, confidence)`.
4. `inference/storage.py` — boto3 helpers: upload a crop to S3, put a
   DynamoDB item.
5. `inference/run_batch.py` — wire the two together against one video path,
   runnable directly with `python run_batch.py <video>` (no S3
   incoming/processed handling yet — that's Sprint 3).

## Definition of Done

- [ ] `terraform apply` creates the bucket + table with no errors.
- [ ] Running `run_batch.py` against a sample video containing both a
      helmeted and unhelmeted rider produces DynamoDB items with correct
      `label`, `camera_id`, `detection_ts`, `confidence`.
- [ ] Each item's `crop_s3_key` points to a real JPEG in `crops/` that is
      visibly a cropped rider frame, not blank/garbage.
- [ ] Reuse-first check done: no bespoke video-decoding or bounding-box code
      written where `ultralytics`/`opencv` already provide it.
