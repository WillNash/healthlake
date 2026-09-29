import boto3
import json
import os


def lambda_handler(event, context):
    job_id = event["job_id"]
    output_bucket = os.environ["IMPORT_OUTPUT_BUCKET"]
    prefix = f"import-output/{job_id}/"

    s3 = boto3.client("s3")
    failures = []

    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=output_bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if "FAILURE" not in key.upper():
                continue
            body = (
                s3.get_object(Bucket=output_bucket, Key=key)["Body"]
                .read()
                .decode("utf-8")
            )
            for line in body.strip().splitlines():
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    failures.append({
                        "resourceType": entry.get("resourceType", "unknown"),
                        "id": entry.get("id", "unknown"),
                        "error": entry.get("errorCause") or entry.get("message", "unknown"),
                    })
                except json.JSONDecodeError:
                    pass

    return {
        "has_failures": bool(failures),
        "failure_count": len(failures),
        "failure_sample": failures[:10],
        "fhir_bucket": event["fhir_bucket"],
        "fhir_key": event["fhir_key"],
        "registry": event["registry"],
        "retry_attempt": event["retry_attempt"],
    }
