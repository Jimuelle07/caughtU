import csv
import io
import os
from datetime import datetime, timedelta, timezone
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
BUCKET = os.environ["BUCKET_NAME"]
SENDER = os.environ["SENDER_EMAIL"]
RECIPIENT = os.environ["RECIPIENT_EMAIL"]
WINDOW_HOURS = int(os.environ.get("WINDOW_HOURS", "8"))

HEADERS = ["detection_id", "camera_id", "detection_ts", "label", "confidence", "crop_s3_key"]

_table = boto3.resource("dynamodb").Table(TABLE_NAME)
_s3 = boto3.client("s3")
_ses = boto3.client("ses")


def handler(event, context):
    # ponytail: window is always "now - WINDOW_HOURS", not anchored to the last
    # successful report, so a late/failed invocation silently drops that gap.
    # Upgrade path: persist last window_end (SSM/DynamoDB) and start there.
    window_end = datetime.now(timezone.utc)
    window_start = window_end - timedelta(hours=WINDOW_HOURS)

    rows = _query_window(window_start, window_end)
    csv_bytes = _build_csv(rows)

    report_key = f"reports/{window_start.isoformat()}_{window_end.isoformat()}.csv"
    _s3.put_object(Bucket=BUCKET, Key=report_key, Body=csv_bytes, ContentType="text/csv")
    _send_email(csv_bytes, report_key, len(rows), window_start, window_end)

    return {"detections": len(rows), "report_key": report_key}


def _query_window(window_start, window_end):
    rows = []
    kwargs = {
        "IndexName": "report_gsi",
        "KeyConditionExpression": "report_bucket = :rb AND detection_ts BETWEEN :start AND :end",
        "ExpressionAttributeValues": {
            ":rb": "ALL",
            ":start": window_start.isoformat(),
            ":end": window_end.isoformat(),
        },
    }
    while True:
        resp = _table.query(**kwargs)
        rows.extend(resp["Items"])
        if "LastEvaluatedKey" not in resp:
            return rows
        kwargs["ExclusiveStartKey"] = resp["LastEvaluatedKey"]


def _build_csv(rows):
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=HEADERS)
    writer.writeheader()
    for row in rows:
        writer.writerow({k: row.get(k) for k in HEADERS})
    return buf.getvalue().encode("utf-8")


def _send_email(csv_bytes, report_key, count, window_start, window_end):
    msg = MIMEMultipart()
    msg["Subject"] = f"caughtU detections: {window_start.isoformat()} - {window_end.isoformat()} ({count})"
    msg["From"] = SENDER
    msg["To"] = RECIPIENT
    msg.attach(MIMEText(f"{count} detection(s) in this window. CSV attached.\n"))

    attachment = MIMEApplication(csv_bytes, _subtype="csv")
    safe_filename = report_key.split("/")[-1].replace(":", "-")
    attachment.add_header("Content-Disposition", "attachment", filename=safe_filename)
    msg.attach(attachment)

    _ses.send_raw_email(
        Source=SENDER,
        Destinations=[RECIPIENT],
        RawMessage={"Data": msg.as_string()},
    )
