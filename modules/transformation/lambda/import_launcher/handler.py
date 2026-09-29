import boto3
import hashlib
import os


def lambda_handler(event, context):
    fhir_bucket = event["fhir_bucket"]
    fhir_key = event["fhir_key"]
    registry = event.get("registry", "unknown")
    retry_attempt = event.get("retry_attempt", 0)

    # Include retry_attempt in the token so each attempt produces a distinct HealthLake job.
    token_seed = fhir_key if retry_attempt == 0 else f"{fhir_key}-retry-{retry_attempt}"
    client_token = hashlib.md5(token_seed.encode()).hexdigest()

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
        "fhir_bucket": fhir_bucket,
        "registry": registry,
        "retry_attempt": retry_attempt,
    }
