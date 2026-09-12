# caughtU

A personal AWS practice project: an automated pipeline that watches CCTV
footage for motorcycle riders **not wearing a helmet**, using YOLOv8/v11 for
detection.

## Problem

Manually reviewing CCTV footage for helmet violations is tedious. This
project automates it end-to-end and doubles as hands-on practice with the AWS
ecosystem (EC2, Lambda, DynamoDB, S3, EventBridge, SES) and Terraform.

## What it does

1. Sample CCTV video files are uploaded to S3.
2. A YOLOv8/v11 model (pretrained on helmet-detection data) scans the footage
   and classifies each rider as `helmet` or `no_helmet`.
3. Every detection — helmet and no-helmet alike — is logged to a database
   with a timestamp, camera/location tag, and a cropped snapshot image.
4. Every 8 hours, a CSV of all detections in that window is emailed out
   automatically.

## Why these choices

- **Batch, not live streaming** — sample video files processed on a schedule,
  not a real-time RTSP feed. Simpler to build and test, and this is a
  learning project, not a live deployment.
- **Pretrained model, not custom-trained** — an existing open-source YOLOv8
  helmet-detection model is used as-is, kept swappable if a better one is
  needed later.
- **GPU compute only runs when needed** — the EC2 GPU instance stays stopped
  by default and only starts when there's footage to process, to keep AWS
  costs near zero when idle.

See `docs/system-design.md` for the full architecture.
