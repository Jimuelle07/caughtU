# caughtU

<p align="center">
  <strong>CCTV helmet-violation detection pipeline leveraging YOLO-based computer vision and cloud infrastructure.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/build-passing-brightgreen" alt="build">
  <img src="https://img.shields.io/badge/release-v1.0.0-blue" alt="release">
  <img src="https://img.shields.io/badge/Ubuntu-22.04+-E95420?logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
</p>

---

**caughtU** is a practice project for automating the detection of helmet violations from CCTV footage. It utilizes a robust, automated pipeline combining machine learning inference with cloud-native, Linux-based infrastructure.

For detailed documentation, refer to:
- [Concept & Idea](docs/idea.md)
- [System Architecture](docs/system-design.md)

## Tech Stack

The system is built on a reliable and scalable technology stack:

- **Machine Learning**: Python, Ultralytics (YOLOv8/v11) for high-speed object detection.
- **Cloud Infrastructure**: AWS (EC2 for compute, S3 for object storage, IAM, boto3).
- **Infrastructure as Code**: Terraform for provisioning.
- **Linux Environment**:
  - **Bash** scripting for instance bootstrapping and automated provisioning (`scripts/bootstrap_ec2.sh`).
  - **Systemd** for robust service management (automated batch inference execution on boot).
  - Designed for **Ubuntu/Debian** Linux runtimes.

## Architecture Overview

The pipeline leverages a transient compute model on AWS EC2 to optimize costs:
1. **Bootstrapping**: An EC2 instance spins up, utilizing Bash scripts to establish the application runtime environment.
2. **Synchronization**: A `systemd` service (`caughtu-inference.service`) safely synchronizes the latest inference code and YOLO weights from S3.
3. **Inference**: The system executes a batch computer-vision workload on pending CCTV footage.
4. **Automated Teardown**: Upon successful completion, the instance safely self-terminates (`/sbin/shutdown -h now`).

## Try It Yourself

**Prerequisites**
- AWS account with credentials configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- A YOLOv8/v11 helmet-detection `.pt` weights file (e.g. from [Roboflow Universe](https://universe.roboflow.com/object-detection-using-yolov8/bike-helmet-detection-2vdjo-semr0))
- A short video clip with a rider to test with

**1. Deploy the infrastructure**
```bash
cd infra
terraform init
terraform apply \
  -var="bucket_suffix=<something-globally-unique>" \
  -var="sender_email=<your-verified-sender>@example.com" \
  -var="recipient_email=<where-reports-go>@example.com"
```

**2. Verify SES**
Check both the sender and recipient inboxes for an AWS verification email and click the confirmation link in each — SES sandbox mode requires this before any email can send.

**3. Upload the model weights**
```bash
aws s3 cp helmet.pt "s3://$(terraform output -raw bucket_name)/models/helmet.pt"
```

**4. Upload a test video**
```bash
aws s3 cp test1.mp4 "s3://$(terraform output -raw bucket_name)/incoming/cam1/test1.mp4"
```

**5. Kick off inference** (or just wait — it runs hourly on its own)
```bash
aws lambda invoke --function-name caughtu-trigger /dev/stdout
```
Watch the EC2 instance (`caughtu-inference`) go `stopped → running`, then back to `stopped` once `run_batch.py` finishes — follow along in CloudWatch Logs (`/aws/lambda/caughtu-trigger` and the instance's own console output).

**6. Check the results**
```bash
aws dynamodb scan --table-name caughtu-detections
aws s3 ls "s3://$(terraform output -raw bucket_name)/crops/cam1/"
aws s3 ls "s3://$(terraform output -raw bucket_name)/processed/cam1/"
```
The source video should be gone from `incoming/cam1/` and present in `processed/cam1/`; a cropped snapshot per detection should be in `crops/cam1/`.

**7. Get the emailed report** (or wait up to 8h — it's on its own schedule)
```bash
aws lambda invoke --function-name caughtu-report /dev/stdout
```
Check the recipient inbox for a CSV attachment listing the detections.

**8. Tear it down** (avoid ongoing AWS charges)
```bash
terraform destroy
```

## Working Method

This repository vendors the **Monozukuri** engineering methodology under `.agents/skills/`.

To maintain quality and deliberate engineering, start any non-trivial change at `.agents/skills/monozukuri-router/SKILL.md` to classify the task and pick the appropriate sequence of skills. *(Note: This methodology is applied inline manually rather than invoked directly as a plugin).*