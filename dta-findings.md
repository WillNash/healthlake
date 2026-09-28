# Research Findings: AWS HealthLake Data Transformation Agent (DTA)

## Source URLs

- [Transforming healthcare data - AWS HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation.html) — **Official**
- [Data Transformation features - AWS HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-features.html) — **Official**
- [How Data Transformation Agent works - AWS HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-how-it-works.html) — **Official**
- [Getting started with the SDK and AWS CLI - AWS HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-getting-started-cli.html) — **Official**
- [Understanding CSV profiles - AWS HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-csv-yaml-reference.html) — **Official**
- [TransformationInputDataConfig - AWS HealthLake API Reference](https://docs.aws.amazon.com/healthlake/latest/APIReference/API_TransformationInputDataConfig.html) — **Official**
- [StartFHIRImportJob - AWS HealthLake API Reference](https://docs.aws.amazon.com/healthlake/latest/APIReference/API_StartFHIRImportJob.html) — **Official**
- [AWS HealthLake endpoints and quotas](https://docs.aws.amazon.com/healthlake/latest/devguide/reference-healthlake-endpoints-quotas.html) — **Official**
- [Integrated natural language processing (NLP) for HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/integrated-medical-nlp.html) — **Official**
- [AWS HealthLake Pricing](https://aws.amazon.com/healthlake/pricing/) — **Official**
- [AWS HealthLake announces data transformation agent for CCDA-to-FHIR conversion (Preview)](https://aws.amazon.com/about-aws/whats-new/2026/03/aws-healthlake-data-transformation-agent) — **Official** (What's New announcement)

---

## 1. GA vs Preview Status

DTA is **still in Preview** as of September 2026. The official AWS docs page states verbatim:

> "Data Transformation Agent is available as a preview capability and is subject to change. The APIs, features, and documentation described in this guide may be modified before general availability."

The What's New announcement was published in **March 2026** and also marks the feature as Preview. There is no GA announcement as of the research date (September 2026). The pricing page explicitly confirms: "Data Transformation AI agent is available in preview. Contact your AWS account team so we can confirm production readiness for your use case."

**Important implication**: Because it is in Preview, the APIs and features may change before GA. Production use should be validated with the AWS account team.

---

## 2. Input Format Support

DTA supports exactly **two source input formats**:

- **C-CDA** (Consolidated Clinical Document Architecture — the XML format for clinical documents)
- **CSV** (arbitrary flat comma-separated files)

**CSV support is explicitly documented and is not limited to any clinical format.** The docs describe CSV as suitable for "CSV exports" from any system. The REDCap flat CSV export format is a plain CSV and is directly supported. There is no requirement that the CSV conform to any healthcare standard — the AI agent infers the FHIR mapping from sample data.

HL7 v2 is **not listed** as a supported input format. Only CCDA and CSV are the valid values for `SourceFormat` in the `TransformationInputDataConfig` API type.

---

## 3. Mapping Customisation for CSV

Yes — full, explicit, arbitrary column-to-FHIR-path mapping is supported. The YAML profile is a **fully declarative document** where you specify:

- Which CSV table maps to which FHIR resource type (e.g., `targetResourceType: Condition`)
- Which column maps to which FHIR path (e.g., `fhirPath: stage.summary.coding[0].code`, `sourceColumn: stage_figo`)
- Transform types: `direct`, `concat`, `dateFormat`, `valueMap`, `expression`, `conditional`, `resourceReference`, `regex`
- Cross-table joins via foreign keys
- Array aggregation (fold child-table rows into FHIR array fields)

The AI agent can generate and edit these YAML mappings from natural language. You can also hand-author the YAML directly without using the agent at all.

Example of a custom field mapping that would cover a REDCap `stage_figo` field:

```yaml
- fhirPath: stage.summary.coding[0].code
  sourceColumn: stage_figo
  transform:
    type: direct
- fhirPath: stage.summary.coding[0].system
  transform:
    type: expression
    params:
      expression: "'http://cancerstaging.org'"
```

The AI agent can also be instructed with natural language like: "Map the RACE_CD column to a FHIR extension" or "Map stage_figo to Condition.stage.summary".

---

## 4. NLP / Comprehend Medical Integration

The NLP / Comprehend Medical capability is a **completely separate HealthLake feature**, entirely distinct from DTA.

- **Integrated NLP** works exclusively on FHIR `DocumentReference` resources that contain unstructured text (e.g., handwritten notes, discharge summaries stored as text blobs in a DocumentReference). It calls Comprehend Medical's `DetectEntities-V2`, `InferICD10-CM`, and `InferRxNorm` APIs and creates linked FHIR `Condition` and `Observation` resources.
- This feature is **turned off by default** and requires a support case to enable.
- It operates **after** data is already in the HealthLake datastore, not during ingestion.
- It has **no relationship to DTA**. DTA converts structured/semi-structured source formats (C-CDA, CSV) into FHIR. NLP handles unstructured free text already stored as DocumentReferences.
- **The NLP feature does NOT work on structured CSV fields.** It only processes the free-text content inside DocumentReference resources.

The claim — *"HealthLake uses built-in natural language processing (Amazon Comprehend Medical) to extract conditions, medications, and procedures"* — refers to the standalone Integrated NLP feature, not to DTA. For REDCap CSV data, this NLP feature is irrelevant unless the CSV contains a column of raw clinical narrative text that gets stored as a DocumentReference.

---

## 5. Region Availability

DTA is available in **ap-southeast-2 (Sydney)**. The official endpoint table lists a dedicated DTA endpoint:

```
datatransformation.healthlake.ap-southeast-2.amazonaws.com
datatransformation.healthlake.ap-southeast-2.api.aws
```

Full DTA region list:
- us-west-2 (Oregon)
- us-east-1 (N. Virginia)
- us-east-2 (Ohio)
- ap-south-1 (Mumbai)
- **ap-southeast-2 (Sydney)** — confirmed
- ca-central-1 (Canada Central)
- eu-west-1 (Ireland)
- eu-west-2 (London)

---

## 6. Pricing

DTA has **no published pricing** while in Preview. The official docs state:

> "Pricing will be announced when the capability becomes generally available."

During the preview period, AWS requires you to contact your account team to discuss production readiness and pricing. Any FHIR data ingested into a HealthLake datastore through DTA is subject to standard HealthLake pricing (storage at $0.25–$0.37/GB/month depending on tier). The Medical NLP feature (separate from DTA) is priced at $0.0010 per 100 characters of analysed text.

---

## 7. StartFHIRImportJob API — DTA-Specific Parameters

When using DTA with `StartFHIRImportJob` (the "convert and ingest" mode), the following parameters are added on top of a plain NDJSON import:

| Parameter | Type | Required for DTA | Description |
|---|---|---|---|
| `ProfileId` | String | Yes | The data transformation profile identifier. Absent in plain NDJSON imports. |
| `InputFormat` | String | Yes | `"CCDA"` or `"CSV"`. Absent in plain NDJSON imports. |
| `DriftDetectionEnabled` | Boolean | No | Enable drift gap reporting. |
| `ProvenanceEnabled` | Boolean | No | Generate FHIR Provenance resources. Defaults to `true`. |
| `ValidationLevel` | String | No | `strict`, `structure-only`, or `minimal`. |

For a **plain NDJSON import** (no DTA), `ProfileId`, `InputFormat`, `DriftDetectionEnabled`, and `ProvenanceEnabled` are all absent. The input S3 URI points to `.ndjson` files containing pre-formed FHIR resources.

Full CLI example for DTA-enabled CSV import into ap-southeast-2:

```bash
aws healthlake start-fhir-import-job \
  --region ap-southeast-2 \
  --datastore-id "your-datastore-id" \
  --input-data-config '{"S3Uri": "s3://your-bucket/redcap-exports/"}' \
  --job-output-data-config '{"S3Configuration": {"S3Uri": "s3://your-output-bucket/import-output/", "KmsKeyId": "arn:aws:kms:ap-southeast-2:123456789012:key/abcd1234"}}' \
  --data-access-role-arn "arn:aws:iam::123456789012:role/DTA-DataAccessRole" \
  --profile-id "your-profile-id" \
  --input-format "CSV" \
  --drift-detection-enabled \
  --job-name "redcap-import" \
  --client-token "import-$(date +%s)"
```

The alternative standalone conversion (output to S3 only, no direct datastore ingestion) uses `StartDataTransformationJob` instead.

---

## Key Quotas (DTA-specific)

| Quota | Default | Adjustable |
|---|---|---|
| CSV files per bulk job | 20 | No |
| Columns per CSV file | 100 | No |
| CSV file size (bulk) | 50 MB | Yes |
| Combined CSV size (sync) | 500 KB | Yes |
| CSV files per sync conversion | 20 | No |
| Concurrent transformation jobs | 1 | Yes |
| Total input per bulk job | 1 GB | Yes |
| Profiles per account | 20 | No |
| Published versions per profile | 99 | No |
| Sync conversion rate | 1 req/sec | Yes |

The **100-column limit per CSV file** is a hard non-adjustable quota. REDCap exports can be wide — this needs to be verified against the specific REDCap instrument export width before committing to DTA.

---

## Gotchas and Warnings

1. **Still in Preview — APIs may change.** Do not build production pipelines on DTA without AWS account team confirmation of production readiness. Pricing is unknown.

2. **100-column limit per CSV file is hard (non-adjustable).** REDCap instruments with more than 100 fields per export file cannot be processed by DTA without splitting the export into narrower files.

3. **20 CSV files per bulk job (non-adjustable).** Large REDCap datasets split across many export files may hit this limit.

4. **AI agent generates YAML from sample data, not full data.** Provide representative samples (including edge cases) and carefully review the generated YAML before production use.

5. **Sync transform is REST-only.** The `TransformData` sync endpoint is not exposed via the AWS CLI or SDK — only via direct REST calls with SigV4 signing.

6. **Concurrent job limit of 1 per account.** A single account can only run one bulk transformation job at a time. Plan scheduling accordingly.

7. **NLP / Comprehend Medical is a completely separate feature.** It is off by default, requires a support case, operates only on DocumentReference free text already in the datastore, and is unrelated to DTA.

8. **CSV profile YAML is empty at creation.** Calling `create-data-transformation-profile` with `SampleData` registers the sample but leaves the YAML mapping empty. You must subsequently call `update-profile-with-agent` to generate the base YAML. This is expected behaviour.

9. **sourceSystemId must be stable.** Changing this field after data is loaded causes duplicate resources because FHIR resource IDs change.

10. **Foreign key references are single-hop only.** Table A can reference Table B, and B can reference C, but A cannot directly reference C through B.
