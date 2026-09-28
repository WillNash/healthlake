import boto3, os
from datetime import datetime

def lambda_handler(event, context):
    hl = boto3.client("healthlake")
    ts = datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    export_prefix = f"exports/{ts}/"
    resp = hl.start_fhir_export_job(
        DatastoreId=os.environ["DATASTORE_ID"],
        OutputDataConfig={"S3Configuration": {
            "S3Uri": f"s3://{os.environ['FHIR_EXPORT_BUCKET']}/{export_prefix}",
            "KmsKeyId": os.environ["KMS_KEY_ARN"]
        }},
        DataAccessRoleArn=os.environ["HEALTHLAKE_EXPORT_ROLE_ARN"],
        JobName=f"fhir-export-{ts}",
    )
    return {"job_id": resp["JobId"], "export_prefix": export_prefix}
