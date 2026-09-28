import boto3, hashlib, json, os

def lambda_handler(event, context):
    """
    Starts HealthLake FHIR import. ClientToken derived from S3 key ensures idempotency on retries.
    """
    detail = event.get("detail", event)
    s3_key = detail["object"]["key"]
    s3_bucket = detail["bucket"]["name"]
    client_token = hashlib.md5(s3_key.encode()).hexdigest()

    hl = boto3.client("healthlake")
    resp = hl.start_fhir_import_job(
        DatastoreId=os.environ["DATASTORE_ID"],
        InputDataConfig={"S3Uri": f"s3://{s3_bucket}/{s3_key}"},
        JobOutputDataConfig={"S3Configuration": {
            "S3Uri": f"s3://{os.environ['IMPORT_OUTPUT_BUCKET']}/",
            "KmsKeyId": os.environ["KMS_KEY_ARN"]
        }},
        DataAccessRoleArn=os.environ["DATA_ACCESS_ROLE_ARN"],
        ClientToken=client_token,
        JobName=f"redcap-import-{client_token[:8]}",
    )
    return {"job_id": resp["JobId"], "s3_key": s3_key}
