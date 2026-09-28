import boto3
import os


def lambda_handler(event, context):
    hl = boto3.client("healthlake")
    resp = hl.describe_fhir_import_job(
        DatastoreId=os.environ["DATASTORE_ID"],
        JobId=event["job_id"],
    )
    job = resp["ImportJobProperties"]
    return {
        "job_id": event["job_id"],
        "status": job["JobStatus"],
        "registry": event.get("registry", "unknown"),
    }
