import boto3
import hashlib
import os


def lambda_handler(event, context):
    """
    Starts a HealthLake FHIR import job against the NDJSON produced by csv_to_fhir_mapper.
    Input: mapper output dict {fhir_bucket, fhir_key, registry, ...}
    ClientToken is derived from fhir_key for idempotent retries.
    """
    fhir_bucket = event["fhir_bucket"]
    fhir_key = event["fhir_key"]
    registry = event.get("registry", "unknown")
    client_token = hashlib.md5(fhir_key.encode()).hexdigest()

    hl = boto3.client("healthlake")
    resp = hl.start_fhir_import_job(
        DatastoreId=os.environ["DATASTORE_ID"],
        InputDataConfig={"S3Uri": f"s3://{fhir_bucket}/{fhir_key}"},
        JobOutputDataConfig={
            "S3Configuration": {
                "S3Uri": f"s3://{os.environ['IMPORT_OUTPUT_BUCKET']}/import-output/",
                "KmsKeyId": os.environ["KMS_KEY_ARN"],
            }
        },
        DataAccessRoleArn=os.environ["DATA_ACCESS_ROLE_ARN"],
        ClientToken=client_token,
        JobName=f"import-{registry}-{client_token[:8]}",
    )
    return {
        "job_id": resp["JobId"],
        "fhir_key": fhir_key,
        "registry": registry,
    }
