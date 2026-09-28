import boto3, json, os

def lambda_handler(event, context):
    """
    Processes free-text FHIR fields via Comprehend Medical.
    HealthLake REST API calls require SigV4 signing (requests-aws4auth).
    HealthLake VPC endpoint must have private_dns_enabled=true.
    """
    free_text_fields = json.loads(os.environ.get("FREE_TEXT_FIELDS", "[]"))
    if not free_text_fields:
        return {"processed": 0}
    # Stub: real implementation uses requests_aws4auth for SigV4-signed POST to HealthLake FHIR endpoint
    return {"processed": 0, "note": "populate with Comprehend Medical entity extraction logic"}
