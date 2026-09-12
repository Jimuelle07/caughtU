import os

import boto3

_s3 = boto3.client("s3")
_ec2 = boto3.client("ec2")

BUCKET = os.environ["BUCKET_NAME"]
INSTANCE_ID = os.environ["INSTANCE_ID"]


# ponytail: this pending/processed diff logic is duplicated in
# inference/run_batch.py. Not shared because the two run in separate
# deployment units (Lambda zip vs. an EC2-fetched script) with no shared-package
# mechanism set up; upgrade path is a Lambda layer + matching install on EC2
# if this drifts.
def _relative_keys(prefix):
    paginator = _s3.get_paginator("list_objects_v2")
    keys = set()
    for page in paginator.paginate(Bucket=BUCKET, Prefix=prefix):
        for obj in page.get("Contents", []):
            if not obj["Key"].endswith("/"):
                keys.add(obj["Key"][len(prefix):])
    return keys


def handler(event, context):
    pending = _relative_keys("incoming/") - _relative_keys("processed/")
    if not pending:
        print("nothing pending, leaving EC2 stopped")
        return {"started": False, "pending": 0}

    print(f"{len(pending)} video(s) pending, starting {INSTANCE_ID}")
    _ec2.start_instances(InstanceIds=[INSTANCE_ID])
    return {"started": True, "pending": len(pending)}
