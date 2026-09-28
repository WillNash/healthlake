import boto3, os

def lambda_handler(event, context):
    hl = boto3.client("healthlake")
    resp = hl.describe_fhir_export_job(DatastoreId=os.environ["DATASTORE_ID"], JobId=event["job_id"])
    job = resp["ExportJobProperties"]
    return {"job_id": event["job_id"], "status": job["JobStatus"], "export_prefix": event["export_prefix"]}
