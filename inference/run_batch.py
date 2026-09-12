import argparse
import tempfile
import traceback
from pathlib import Path

import boto3

from detect import run_detection
from storage import save_detection

DEFAULT_WEIGHTS = Path(__file__).parent / "weights" / "helmet.pt"


def _relative_keys(s3, bucket, prefix):
    paginator = s3.get_paginator("list_objects_v2")
    keys = set()
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            if not obj["Key"].endswith("/"):
                keys.add(obj["Key"][len(prefix):])
    return keys


def _process_video(s3, bucket, key, camera_id, weights, sample_fps):
    with tempfile.TemporaryDirectory() as tmp:
        local_path = Path(tmp) / Path(key).name
        s3.download_file(bucket, key, str(local_path))

        count = 0
        for frame_ts, label, bbox, confidence, crop_jpg in run_detection(local_path, weights, sample_fps):
            save_detection(bucket, camera_id, key, label, confidence, crop_jpg)
            count += 1
            print(f"[{frame_ts:6.1f}s] {label} ({confidence:.2f})")

    processed_key = "processed/" + key[len("incoming/"):]
    s3.copy_object(Bucket=bucket, CopySource={"Bucket": bucket, "Key": key}, Key=processed_key)
    s3.delete_object(Bucket=bucket, Key=key)
    print(f"{key}: {count} detection(s), moved to {processed_key}")


def main():
    parser = argparse.ArgumentParser(description="Process every pending video in S3 incoming/ not yet in processed/")
    parser.add_argument("--bucket", required=True, help="S3 bucket (terraform output: bucket_name)")
    parser.add_argument("--weights", default=str(DEFAULT_WEIGHTS))
    parser.add_argument("--sample-fps", type=float, default=1.0)
    args = parser.parse_args()

    s3 = boto3.client("s3")
    pending = _relative_keys(s3, args.bucket, "incoming/") - _relative_keys(s3, args.bucket, "processed/")
    print(f"{len(pending)} video(s) pending")

    for rel in sorted(pending):
        key = "incoming/" + rel
        camera_id = rel.split("/")[0]
        try:
            _process_video(s3, args.bucket, key, camera_id, args.weights, args.sample_fps)
        except Exception:
            # ponytail: a video that fails partway through stays in incoming/ and is
            # retried whole on the next run, re-saving already-written detections
            # under new ids. Upgrade path: track last-processed frame (e.g. S3
            # object metadata) to resume instead of restart.
            print(f"error processing {key}, skipping:")
            traceback.print_exc()


if __name__ == "__main__":
    main()
