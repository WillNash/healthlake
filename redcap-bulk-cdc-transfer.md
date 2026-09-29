# REDCap → HealthLake: Bulk Bootstrap + Continuous Ingestion

## Overview

Moving a REDCap project into HealthLake requires two distinct phases:

1. **Bulk bootstrap** — a one-time historical export of all existing records
2. **Continuous ingestion** — ongoing near-real-time capture of new and updated records

The challenge is ensuring no records are missed or duplicated at the transition boundary. The solution is not a clean hard cutover — it is **idempotent writes with a durable watermark**, so the overlap window between phases is self-resolving.

---

## Core requirement: deterministic FHIR resource IDs

Both phases must write to HealthLake using `PUT` with resource IDs you control, derived deterministically from the REDCap record identifier:

```
PUT /r4/Patient/redcap-{project_id}-{record_id}
```

Do not use `POST`, which lets HealthLake assign IDs. If bulk and continuous both `POST` the same logical record, HealthLake creates two distinct resources. With `PUT` and a deterministic ID, any overlap is a safe upsert — last write wins.

This ID scheme must be consistent across the bulk export, the catch-up pass, and the continuous path.

---

## Phase ordering

```
T0 ──────────────────────── T1 ──────────────────────────→ now
│                            │
│  bulk export running        │  continuous ingestion
│  (all records, full)        │  (records modified since T0)
│                            │
│← catch-up export: T0 → T1 →│
```

### T0: Enable the buffer before anything exports

Configure the REDCap Data Entry Trigger (webhook) to send notifications into an SQS queue. **Do not start processing the queue yet** — it is buffering only. Record `T0` as an ISO8601 timestamp.

This ordering is critical. Enabling the webhook after the bulk completes creates a gap: any record saved during the bulk export is captured by neither path.

### T1: Bulk export completes

Export all records from REDCap with no date filter. Transform each record to FHIR and write to HealthLake via `PUT`. Record `T1` as the bulk completion timestamp.

### Catch-up pass

Use the REDCap API `dateRangeBegin` / `dateRangeEnd` parameters to export records modified between `T0` and `T1`. These are records that changed while the bulk was running. Write them as `PUT`s. Because the IDs are deterministic, records already imported by the bulk are safely overwritten with their latest state.

### Drain and switch

Begin consuming the SQS queue. Each message is a webhook notification (REDCap sends metadata only — project ID, record ID, instrument, event). The Lambda handler calls back to the REDCap API to fetch the full record, transforms it to FHIR, and writes to HealthLake via `PUT`.

Records in the SQS queue that overlap with the bulk or catch-up pass are resolved by the same upsert semantics — no special handling required.

---

## Watermark

Store the pipeline state in SSM Parameter Store, keyed by project:

| Parameter | Value | Set when |
|---|---|---|
| `/pipeline/{project_id}/bulk_complete_at` | `T1` (ISO8601) | Bulk export finishes |
| `/pipeline/{project_id}/last_processed_at` | Updated per run | After each successful continuous run |

After the catch-up pass completes, initialise `last_processed_at` to `T1`. The continuous path reads this value on every run and uses it as `dateRangeBegin` for the REDCap API call. After a successful run it writes `now` back to the parameter.

The watermark is what allows the continuous path to be restarted safely — a failed or interrupted run leaves `last_processed_at` at its previous value, so the next run re-processes the same window.

---

## Continuous ingestion: two options

### Option A — Micro-batch (recommended starting point)

EventBridge Scheduler fires every N minutes. A Lambda calls the REDCap API with `dateRangeBegin = last_processed_at`, exports changed records, transforms to FHIR, writes to HealthLake, and updates the watermark.

- Lag: N minutes (5 minutes is a reasonable default for most clinical workflows)
- No webhook infrastructure required
- Reliable: scheduler and SSM are both highly available managed services
- Simpler error handling: a failed run retries the same window on the next tick

### Option B — Webhook-driven (near-real-time)

REDCap Data Entry Trigger → API Gateway → SQS → Lambda. Each SQS message triggers a Lambda that fetches the specific record from REDCap, transforms it, and writes to HealthLake.

- Lag: seconds after a clinician saves a record
- Requires REDCap admin access to configure the Data Entry Trigger per project
- REDCap webhook sends metadata only (record ID, instrument, event) — the Lambda must call back to the REDCap API for the record data, requiring outbound network access
- Reliability varies by REDCap hosting environment; the SQS buffer absorbs webhook bursts
- Per-record error handling required (DLQ on SQS)

**Recommendation:** start with Option A. The trigger mechanism is the only difference between the two options — HealthLake writes and the watermark logic are identical. Option B can be introduced later without changing the ingestion or storage layer.

---

## Failure handling at each phase

### Bulk export

If the bulk export fails partway through, it is safe to restart from the beginning. Because writes are idempotent `PUT`s, re-exporting records already in HealthLake produces the correct result. Do not attempt to resume from a partial export — restart cleanly and do not set `bulk_complete_at` until the full export succeeds.

### Catch-up pass

Re-runnable by design. Re-exporting `T0 → T1` again after a failure is safe.

### Continuous ingestion (micro-batch)

If a run fails before updating `last_processed_at`, the next run retries the same `dateRangeBegin` window. Records processed in the failed run are re-processed and upserted — safe because writes are idempotent.

If a run fails after updating `last_processed_at`, the window between the failed run's start and the written timestamp is lost. To prevent this, update the watermark only after all HealthLake writes for a run have confirmed successfully.

### Continuous ingestion (webhook)

Configure a DLQ on the SQS queue. Failed Lambda invocations (REDCap API unreachable, FHIR validation error, HealthLake throttle) are retried by SQS up to `maxReceiveCount` times before landing on the DLQ. Monitor the DLQ and alert on any messages — each represents a record that did not reach HealthLake.

---

## Individual record failures in HealthLake

HealthLake bulk import reports job-level status (`COMPLETED`, `FAILED`) but writes per-resource success and failure detail to the output S3 bucket. A `COMPLETED` job may contain individual resource rejections. The current pipeline does not inspect the output files — a failed resource is silently dropped.

For the continuous path (direct FHIR REST `PUT`) this is not an issue — each HTTP response is per-resource and failures are immediately visible to the caller.

If the bulk import path is retained, add a post-import step that reads the HealthLake output manifest from S3 and routes any per-resource errors to SNS or a DLQ.

---

## What changes in the current codebase

| Concern | Current behaviour | Required change |
|---|---|---|
| FHIR resource IDs | HealthLake assigns IDs (via bulk import `POST` semantics) | Switch to `PUT` with deterministic IDs in `csv_to_fhir_mapper` |
| HealthLake write path | Bulk import job (async S3 pull) | FHIR Bundle `PUT` for continuous; bulk import may be retained for bootstrap only |
| Trigger | Nightly EventBridge Scheduler | Scheduler retained for continuous micro-batch; one-shot execution for bulk |
| State | None | `last_processed_at` watermark in SSM Parameter Store |
| REDCap export filter | Full export, no date filter | `dateRangeBegin = last_processed_at` for continuous runs |
| Per-resource failure visibility | Silent (bulk import output not inspected) | HTTP response per `PUT` in continuous path; output manifest check for bulk |
