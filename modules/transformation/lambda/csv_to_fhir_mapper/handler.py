import boto3
import csv
import io
import json
import os
from datetime import datetime, timezone

REGISTRY_MAP = json.loads(os.environ.get("REGISTRY_MAP", "{}"))
_KNOWN = frozenset(["ovarian_cancer", "cardiac_surgery"])


def lambda_handler(event, context):
    detail = event.get("detail", event)
    bucket = detail["bucket"]["name"]
    key = detail["object"]["key"]

    registry = _detect_registry(key)

    s3 = boto3.client("s3")
    obj = s3.get_object(Bucket=bucket, Key=key)
    csv_text = obj["Body"].read().decode("utf-8-sig")  # strip BOM if present

    mapping_fn = _get_mapping_fn(registry)
    reader = csv.DictReader(io.StringIO(csv_text))

    resources = []
    skipped = 0
    for row in reader:
        row_resources = mapping_fn(row)
        if row_resources:
            resources.extend(row_resources)
        else:
            skipped += 1

    ndjson = "\n".join(json.dumps(r, separators=(",", ":")) for r in resources)

    staging_bucket = os.environ["FHIR_STAGING_BUCKET"]
    ts = datetime.now(timezone.utc).strftime("%Y/%m/%d/%H%M%S")
    out_key = f"fhir-ndjson/{registry}/{ts}.ndjson"

    s3.put_object(
        Bucket=staging_bucket,
        Key=out_key,
        Body=ndjson.encode("utf-8"),
        ContentType="application/fhir+ndjson",
        ServerSideEncryption="aws:kms",
    )

    return {
        "fhir_bucket": staging_bucket,
        "fhir_key": out_key,
        "resource_count": len(resources),
        "skipped_rows": skipped,
        "registry": registry,
        "source_key": key,
    }


def _detect_registry(key: str) -> str:
    # Simulation path: redcap-exports/{registry}/...
    parts = key.split("/")
    if len(parts) >= 2 and parts[1] in _KNOWN:
        return parts[1]
    # Production path: redcap-exports/{YYYY}/{MM}/{DD}/{HHMMSS}-{project_id}.csv
    filename = parts[-1]
    for project_id, registry in REGISTRY_MAP.items():
        if filename.endswith(f"-{project_id}.csv"):
            return registry
    return "unknown"


def _get_mapping_fn(registry: str):
    if registry == "ovarian_cancer":
        from mappings.ovarian_cancer import map_row
        return map_row
    if registry == "cardiac_surgery":
        from mappings.cardiac_surgery import map_row
        return map_row
    raise ValueError(
        f"No mapping found for registry: {registry!r}. "
        "Add project_id to REGISTRY_MAP or use a named simulate path."
    )
