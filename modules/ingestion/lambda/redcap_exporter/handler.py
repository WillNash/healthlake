import boto3
import json
import os
import urllib.request
from datetime import datetime


def lambda_handler(event, context):
    """
    Exports REDCap records as CSV and writes to S3 landing bucket.
    Uses urllib (no requests library needed for basic HTTP POST).
    """
    sm = boto3.client("secretsmanager")
    secret = json.loads(
        sm.get_secret_value(SecretId=os.environ["SECRET_ARN"])["SecretString"]
    )
    token = secret["token"]

    s3 = boto3.client("s3")
    bucket = os.environ["LANDING_BUCKET"]
    url = os.environ["REDCAP_URL"].rstrip("/") + "/api/index.php"
    project_id = os.environ["REDCAP_PROJECT_ID"]

    payload = "&".join(
        [
            f"token={token}",
            "content=record",
            "format=csv",
            "type=flat",
            "rawOrLabel=raw",
            "exportDataAccessGroups=true",
        ]
    ).encode("utf-8")

    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urllib.request.urlopen(req, timeout=120) as resp:
        csv_data = resp.read()

    ts = datetime.utcnow().strftime("%Y/%m/%d/%H%M%S")
    key = f"redcap-exports/{ts}-{project_id}.csv"
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=csv_data,
        ContentType="text/csv",
        ServerSideEncryption="aws:kms",
    )
    return {"bucket": bucket, "key": key}
