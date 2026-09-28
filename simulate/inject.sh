#!/usr/bin/env bash
# Injects a sample REDCap CSV into the S3 landing bucket to trigger the full pipeline.
#
# Usage:
#   ./simulate/inject.sh <registry> <landing-bucket-name>
#
# Examples:
#   ./simulate/inject.sh ovarian_cancer clinical-registry-dev-landing-abc123
#   ./simulate/inject.sh cardiac_surgery clinical-registry-dev-landing-abc123
#   ./simulate/inject.sh heartland_hf clinical-registry-dev-landing-abc123
#
# The landing bucket name is available from Terraform:
#   terraform -chdir=environments/dev output landing_bucket_name
#
# What happens after injection:
#   1. S3 ObjectCreated event fires via EventBridge
#   2. Step Functions execution starts (import-orchestrator state machine)
#   3. csv_to_fhir_mapper Lambda reads the CSV and writes FHIR NDJSON to fhir-staging
#   4. import_launcher Lambda starts a HealthLake FHIR import job
#   5. import_poller Lambda polls until COMPLETED or FAILED
#
# Monitor progress:
#   aws stepfunctions list-executions \
#     --state-machine-arn $(terraform -chdir=environments/dev output -raw sfn_state_machine_arn) \
#     --query 'executions[0]'

set -euo pipefail

REGISTRY="${1:-}"
BUCKET="${2:-}"

if [[ -z "$REGISTRY" || -z "$BUCKET" ]]; then
  echo "Usage: $0 <registry> <landing-bucket-name>"
  echo "  registries: ovarian_cancer, cardiac_surgery, heartland_hf"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="${SCRIPT_DIR}/registries/${REGISTRY}/export.csv"

if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: sample CSV not found at ${CSV_FILE}"
  echo "Available registries: $(ls "${SCRIPT_DIR}/registries/")"
  exit 1
fi

TIMESTAMP=$(date -u +"%Y/%m/%d/%H%M%S")
# Use registry name as path segment so the mapper can detect it without a REGISTRY_MAP entry.
S3_KEY="redcap-exports/${REGISTRY}/${TIMESTAMP}-sim.csv"

echo "Uploading ${CSV_FILE} → s3://${BUCKET}/${S3_KEY}"

aws s3 cp "$CSV_FILE" "s3://${BUCKET}/${S3_KEY}" \
  --sse aws:kms \
  --content-type "text/csv"

echo ""
echo "Upload complete. The Step Functions execution should start within ~30 seconds."
echo ""
echo "To watch executions:"
echo "  aws stepfunctions list-executions \\"
echo "    --state-machine-arn \$(terraform -chdir=environments/dev output -raw sfn_state_machine_arn)"
