import boto3, json, os

def lambda_handler(event, context):
    """Invoked by transformation SFN COMPLETED branch. Starts analytics export Step Functions."""
    sfn = boto3.client("stepfunctions")
    sfn.start_execution(stateMachineArn=os.environ["EXPORT_ETL_SFN_ARN"], input=json.dumps(event))
    return {"started": True}
