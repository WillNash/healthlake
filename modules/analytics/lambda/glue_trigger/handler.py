import boto3, os

def lambda_handler(event, context):
    glue = boto3.client("glue")
    resp = glue.start_job_run(
        JobName=os.environ["GLUE_JOB_NAME"],
        Arguments={"--export_prefix": event["export_prefix"], "--fhir_export_bucket": os.environ["FHIR_EXPORT_BUCKET"]}
    )
    return {"job_run_id": resp["JobRunId"]}
