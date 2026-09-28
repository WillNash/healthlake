# Input Size Constraints

Size limits that apply to the REDCap CSV → HealthLake pipeline, from the S3 upload
through to the HealthLake import job.

---

## Summary

| Layer | Limit | Binding? |
|---|---|---|
| S3 input object | 5 TB | No |
| EventBridge event | 256 KB (metadata only — file content never included) | No |
| Step Functions state I/O | 256 KB (metadata only passed between states) | No |
| Lambda timeout | 300 seconds | Unlikely at REDCap scale |
| **Lambda memory** | **256 MB allocated, ~150–200 MB usable** | **Yes** |

---

## Layer-by-layer detail

### S3 input object — 5 TB

No practical constraint. S3 supports objects up to 5 TB. The EventBridge event triggered
by the upload contains only the object key and metadata — not the file content — so object
size has no downstream effect on EventBridge or Step Functions.

### EventBridge event — 256 KB

The S3 `Object Created` event payload contains bucket name, object key, size, ETag, and
other metadata. It does not contain the file content. The 256 KB EventBridge event size
limit is nowhere near being reached by an S3 notification event.

### Step Functions state I/O — 256 KB

Each state transition in Step Functions is subject to a 256 KB payload limit. This is not
a concern here because the `csv_to_fhir_mapper` Lambda returns only metadata:

```json
{
  "fhir_bucket": "clinical-registry-dev-fhir-staging-abc123",
  "fhir_key": "fhir-ndjson/heartland_hf/2026/09/28/120001.ndjson",
  "resource_count": 340,
  "skipped_rows": 0,
  "registry": "heartland_hf",
  "source_key": "redcap-exports/heartland_hf/2026-09-28T120000-sim.csv"
}
```

The actual data moves directly between S3 and Lambda and never passes through a state
boundary. This limit would only become relevant if file content were embedded in SFN state,
which it is not.

### Lambda timeout — 300 seconds

Configured at `modules/transformation/main.tf:159`. Could theoretically be reached before
the memory limit for extremely large exports with compute-intensive mapping logic. Not a
realistic constraint at REDCap export volumes.

### Lambda memory — 256 MB (the binding constraint)

Configured at `modules/transformation/main.tf:160`. This is the limit that will be hit
first with large input files.

`handler.py:21` reads the entire CSV into a single Python string in memory:

```python
csv_text = obj["Body"].read().decode("utf-8-sig")
```

`handler.py:35` then serialises all generated FHIR resources into a second string:

```python
ndjson = "\n".join(json.dumps(r, separators=(",", ":")) for r in resources)
```

At peak, the Lambda is holding all of the following simultaneously:

- the raw CSV text
- the `resources` list of FHIR dicts (one dict per FHIR resource)
- the NDJSON output string

FHIR resources are verbose JSON. Each CSV row typically expands to 3–8 resources at a
few hundred bytes each — a rough **5–10× expansion** from CSV to NDJSON. With 256 MB
allocated and approximately 50–80 MB consumed by the Python 3.12 runtime and imports,
the usable working memory is roughly **150–200 MB**. This puts a practical ceiling of
around **20–40 MB of CSV input**, depending on how many resources the registry mapping
produces per row.

If this limit is exceeded, Lambda throws an out-of-memory error and the Step Functions
`Catch` block routes execution to `NotifyFailure`, publishing the failure detail to the
`import-failures` SNS topic.

---

## Increasing the limit

### Option 1 — Raise Lambda memory

Lambda allows up to 10,240 MB. Increasing `memory_size` in
`modules/transformation/main.tf:160` raises both the memory ceiling and the available
CPU (Lambda allocates CPU proportionally to memory), which also helps with timeout risk.
This is a one-line Terraform change followed by `terraform apply`.

```hcl
memory_size = 1024  # raise from 256 MB
```

### Option 2 — Stream rather than buffer

Replace the full-file read and full-NDJSON-string pattern with a streaming approach:
read one CSV row at a time, produce FHIR resources for that row, serialise them, and
append directly to an S3 multipart upload stream. Memory usage drops to roughly constant
regardless of file size — only one row's worth of resources is in memory at any point.

This is the correct fix for production-scale exports. It requires replacing
`obj["Body"].read()` with an incremental `StreamingBody` read, and replacing
`s3.put_object(Body=ndjson)` with the S3 multipart upload API
(`create_multipart_upload` / `upload_part` / `complete_multipart_upload`).

### Option 3 — Split large REDCap exports before upload

If the REDCap export process is under your control, split exports larger than ~15 MB
into multiple files before uploading to the landing bucket. Each file triggers an
independent pipeline execution. No Lambda changes required, but requires coordination
with the REDCap export workflow.

---

## Context: typical REDCap export sizes

A REDCap export for a single instrument with 10,000 patient records and 50 fields is
typically 5–15 MB as a flat CSV — well within the current 256 MB Lambda limit. The
constraint only becomes relevant at tens of thousands of records or very wide exports
(many calculated fields, long free-text columns). For the POC with synthetic data and
five registries, the current configuration is sufficient.
