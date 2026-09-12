#!/bin/bash
set -euo pipefail

APP_DIR=/opt/caughtu
mkdir -p $APP_DIR/inference $APP_DIR/weights

pip3 install --no-input ultralytics boto3

# Code + weights are re-synced from S3 on every boot (ExecStartPre below), not
# just here at first launch -- a later `terraform apply` (which re-uploads to
# s3://.../code/) reaches the instance on its next start without re-baking an
# AMI or hand-restarting anything.
cat > /etc/systemd/system/caughtu-inference.service <<UNIT
[Unit]
Description=caughtU batch inference, runs once per boot then shuts the instance down
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$APP_DIR/inference
ExecStartPre=/usr/bin/env aws s3 cp --recursive s3://${bucket_name}/code/ $APP_DIR/inference/ --region ${aws_region}
ExecStartPre=/usr/bin/env aws s3 cp s3://${bucket_name}/models/helmet.pt $APP_DIR/weights/helmet.pt --region ${aws_region}
ExecStart=/bin/bash -c '/usr/bin/python3 run_batch.py --bucket ${bucket_name} --weights $APP_DIR/weights/helmet.pt ; /sbin/shutdown -h now'

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable caughtu-inference.service
