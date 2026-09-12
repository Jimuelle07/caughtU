<h1 align="center">caughtU</h1>

<p align="center">
  <strong>CCTV helmet-violation detection pipeline built on YOLO computer vision and cloud-native AWS infrastructure.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/build-passing-brightgreen" alt="Build">
  <img src="https://img.shields.io/badge/release-v1.0.0-blue" alt="Release">
  <img src="https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Ubuntu-22.04+-E95420?logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Terraform-1.5+-7B42BC?logo=terraform&logoColor=white" alt="Terraform">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
</p>

---

## Overview

**caughtU** automates the detection of motorcycle helmet violations from CCTV footage. Video lands in object storage, a scheduled trigger spins up a transient GPU-free compute instance, a batch YOLO workload scores the footage, and the results are persisted and emailed as a report — with no long-running servers in between.

This is a practice project built to exercise end-to-end ML infrastructure: inference, provisioning, service management, and cost-aware compute.

**Further reading**

| Document | Contents |
| --- | --- |
| [Concept & Idea](docs/idea.md) | Problem framing, scope, and design rationale |
| [System Architecture](docs/system-design.md) | Component breakdown and data flow |

## Tech Stack

| Layer | Technology |
| --- | --- |
| Computer vision | Python 3.10+, Ultralytics (YOLOv8 / YOLOv11) |
| Compute | AWS EC2 (transient batch), AWS Lambda (trigger & reporting) |
| Storage | Amazon S3 (footage, crops, weights), DynamoDB (detections) |
| Notifications | Amazon SES |
| Infrastructure as code | Terraform >= 1.5 |
| Runtime | Ubuntu / Debian, Bash bootstrapping, `systemd` service management |
| Access & SDK | IAM, boto3 |

## Architecture

```
S3 incoming/  →  Lambda (caughtu-trigger)  →  EC2 (caughtu-inference)
                                                      │
                                                      ▼
                          DynamoDB (caughtu-detections) + S3 crops/ + S3 processed/
                                                      │
                                                      ▼
                                Lambda (caughtu-report)  →  SES  →  CSV email
```

The pipeline uses a transient compute model to keep costs near zero when idle:

1. **Bootstrap** — an EC2 instance starts and runs a Bash provisioning script (`scripts/bootstrap_ec2.sh`) to establish the application runtime.
2. **Synchronize** — the `caughtu-inference.service` unit pulls the latest inference code and YOLO weights from S3.
3. **Infer** — a batch computer-vision workload processes all pending CCTV footage, writing detections to DynamoDB and cropped snapshots to S3.
4. **Tear down** — on successful completion the instance shuts itself down (`/sbin/shutdown -h now`), so compute is billed only for the duration of the batch.

## Quickstart

### Prerequisites

- An AWS account with credentials configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- A YOLOv8/v11 helmet-detection `.pt` weights file — e.g. from [Roboflow Universe](https://universe.roboflow.com/object-detection-using-yolov8/bike-helmet-detection-2vdjo-semr0)
- A short test clip containing a rider

### 1. Deploy the infrastructure

```bash
cd infra
terraform init
terraform apply \
  -var="bucket_suffix=<something-globally-unique>" \
  -var="sender_email=<your-verified-sender>@example.com" \
  -var="recipient_email=<where-reports-go>@example.com"
```

### 2. Verify SES identities

Check both the sender and recipient inboxes for an AWS verification email and confirm each. SES sandbox mode blocks all sending until both identities are verified.

### 3. Upload the model weights

```bash
aws s3 cp helmet.pt "s3://$(terraform output -raw bucket_name)/models/helmet.pt"
```

### 4. Upload a test video

```bash
aws s3 cp test1.mp4 "s3://$(terraform output -raw bucket_name)/incoming/cam1/test1.mp4"
```

### 5. Kick off inference

The trigger runs hourly on its own, or invoke it directly:

```bash
aws lambda invoke --function-name caughtu-trigger /dev/stdout
```

Watch the `caughtu-inference` instance transition `stopped → running → stopped` as `run_batch.py` completes. Follow along in CloudWatch Logs (`/aws/lambda/caughtu-trigger`) and the instance console output.

### 6. Check the results

```bash
aws dynamodb scan --table-name caughtu-detections
aws s3 ls "s3://$(terraform output -raw bucket_name)/crops/cam1/"
aws s3 ls "s3://$(terraform output -raw bucket_name)/processed/cam1/"
```

The source video should have moved from `incoming/cam1/` to `processed/cam1/`, with one cropped snapshot per detection under `crops/cam1/`.

### 7. Generate the report

Reporting runs on an 8-hour schedule, or invoke it directly:

```bash
aws lambda invoke --function-name caughtu-report /dev/stdout
```

The recipient inbox receives a CSV attachment listing the detections.

### 8. Tear down

```bash
terraform destroy
```

Run this when you're done to avoid ongoing AWS charges.

## Working Method

This repository vendors the **Monozukuri** engineering methodology under `.agents/skills/`.

Any non-trivial change should start at `.agents/skills/monozukuri-router/SKILL.md`, which classifies the task and selects the appropriate sequence of skills. The methodology is currently applied inline and manually rather than invoked as a plugin.

## License

Released under the [MIT License](LICENSE).
