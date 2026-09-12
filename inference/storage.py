import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import boto3

_s3 = boto3.client("s3")
_table = boto3.resource("dynamodb").Table("caughtu-detections")

_last_ts = {}  # camera_id -> last-used timestamp, nudged forward to guarantee
                # the (camera_id, detection_ts) key stays unique even when two
                # detections in the same frame land in the same instant.


def _next_ts(camera_id):
    now = datetime.now(timezone.utc)
    last = _last_ts.get(camera_id)
    if last is not None and now <= last:
        now = last + timedelta(microseconds=1)
    _last_ts[camera_id] = now
    return now.isoformat()


def save_detection(bucket, camera_id, source_video_key, label, confidence, crop_jpg):
    detection_id = str(uuid.uuid4())
    crop_key = f"crops/{camera_id}/{detection_id}.jpg"
    _s3.put_object(Bucket=bucket, Key=crop_key, Body=crop_jpg, ContentType="image/jpeg")

    _table.put_item(Item={
        "camera_id": camera_id,
        "detection_ts": _next_ts(camera_id),
        "detection_id": detection_id,
        "label": label,
        "crop_s3_key": crop_key,
        "source_video_key": source_video_key,
        "confidence": Decimal(str(confidence)),
        "report_bucket": "ALL",
    })
    return detection_id
