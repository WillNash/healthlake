# Simulate

Drop synthetic REDCap exports into the pipeline without needing a live REDCap instance.

## Quick start

```bash
# Get the landing bucket name from Terraform output
BUCKET=$(terraform -chdir=environments/dev output -raw landing_bucket_name)

# Inject an ovarian cancer registry export
./simulate/inject.sh ovarian_cancer $BUCKET

# Inject a cardiac surgery registry export
./simulate/inject.sh cardiac_surgery $BUCKET
```

`inject.sh` uploads the CSV to `s3://<bucket>/redcap-exports/<registry>/<timestamp>-sim.csv`.
The EventBridge rule on the landing bucket fires immediately and starts the Step Functions
execution, which runs the mapper → HealthLake import chain.

## How registry detection works

The mapper detects the registry from the S3 key path. When the second path segment
matches a known registry name (`ovarian_cancer`, `cardiac_surgery`), that name is used
directly. This is the simulation path.

In production, the REDCap exporter writes keys like
`redcap-exports/YYYY/MM/DD/HHMMSS-{project_id}.csv`. The mapper looks up the project ID
in the `REGISTRY_MAP` Lambda environment variable. Set this via the `registry_map`
Terraform variable once you know the project IDs of the live REDCap projects.

```hcl
# environments/dev/terraform.tfvars
registry_map = {
  "1001" = "ovarian_cancer"
  "1002" = "cardiac_surgery"
}
```

## Sample data

| Registry | File | Records | Notes |
|---|---|---|---|
| Ovarian cancer | `registries/ovarian_cancer/export.csv` | 5 | NHI prefix ZZZ, clearly synthetic |
| Cardiac surgery | `registries/cardiac_surgery/export.csv` | 5 | NHI prefix ZZZ, clearly synthetic |

All records use NHI numbers with the `ZZZ` prefix, which is not allocated by the
NHI authority and cannot collide with real patients.

## Adding a new registry

1. Create `registries/<registry_name>/export.csv` with the REDCap flat export format
   for that project (use `ZZZ` NHI prefix, synthetic dates, fabricated data only).
2. Create `registries/<registry_name>/mapping_spec.md` documenting the intended field
   mappings — this is the working document for the clinical concept agreement meeting.
3. Add a mapping module at
   `modules/transformation/lambda/csv_to_fhir_mapper/mappings/<registry_name>.py`.
4. Register it in `_get_mapping_fn()` in `handler.py`.

## Mapping specs

Each registry directory contains a `mapping_spec.md`. These are working documents for
the clinical concept agreement process — the point in the pipeline where the clinical
team reviews field definitions and agrees on SNOMED CT codes. The mapper code must not
go to production until the spec has been reviewed and the SNOMED codes confirmed via the
NZ Terminology Service.
