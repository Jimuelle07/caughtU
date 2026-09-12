# Sprint 002 — Automated GPU compute

- id: 2
- intent: The EC2 GPU instance boots, runs the Sprint 1 inference logic
  against whatever's pending, and stops itself — no manual babysitting, and
  no idle GPU billing.
- affected: `infra/ec2.tf`, `infra/iam.tf` (EC2 role), `scripts/bootstrap_ec2.sh`,
  `inference/run_batch.py` (extend to read/write S3 `incoming/`/`processed/`
  instead of a local path)
- prereqs: 1
- playbook: feature
- risk: high (first cost-bearing resource — a misconfigured shutdown
  behavior or stuck script can leave a GPU instance running and billing)

## Tasks

1. Terraform: `aws_instance` (`g4dn.xlarge`), security group (SSH-in for
   debugging only, no inbound needed otherwise),
   `instance_initiated_shutdown_behavior = "stop"` (**verify this explicitly
   — getting it wrong terminates instead of stops the instance**), EC2 IAM
   role scoped per `system-design.md` § IAM.
2. `scripts/bootstrap_ec2.sh` (user-data, runs once at first launch):
   installs CUDA/ultralytics deps, downloads the model from
   `s3://caughtu-media/models/`, installs a systemd unit
   (`caughtu-inference.service`, `Type=oneshot`, enabled at boot).
3. Extend `run_batch.py` to list `incoming/<camera_id>/`, process each
   pending video, move it to `processed/<camera_id>/` on success, then exit
   (systemd unit's `ExecStop`/completion triggers `shutdown -h now`).

## Definition of Done

- [ ] `terraform apply` creates the instance in a **stopped** state.
- [ ] Manually starting the instance (console or CLI) with a video already
      in `incoming/` results in: inference runs, DynamoDB items + crops
      appear, the video moves to `processed/`, and the instance returns to
      `stopped` **on its own**, with no manual stop needed.
- [ ] Confirmed via console/CloudWatch that the instance did not
      accidentally terminate (state history shows `stopped`, not
      `terminated`).
- [ ] Starting the instance with `incoming/` already empty still completes
      cleanly and self-stops (no crash on the empty case).
- [ ] Poka-yoke check: a bad/corrupt video file in `incoming/` doesn't hang
      the script indefinitely (wrap per-video processing in an error handler
      that logs and continues, so shutdown still fires).
