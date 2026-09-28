# Ovarian Cancer Registry — field-to-FHIR mapping spec

**Status: DRAFT — requires clinical team sign-off before production use.**
SNOMED CT concept selection must be confirmed via the NZ Terminology Service
(https://nzhts.digital.health.nz) with the clinical lead for this registry.

## REDCap fields

| Field | Type | Values | FHIR target |
|---|---|---|---|
| `record_id` | int | unique | Resource ID suffix |
| `nhi_number` | string | NHI (old format) | `Patient.identifier` (system: NHI) |
| `dob` | date | YYYY-MM-DD | `Patient.birthDate` |
| `sex` | radio | 0=Unknown, 1=Female, 2=Male | `Patient.gender` |
| `ethnicity` | radio | 1=NZ European, 2=Māori, 3=Pacific, 4=Asian, 9=Other | Patient extension (pending) |
| `diagnosis_date` | date | YYYY-MM-DD | `Condition.onsetDateTime` |
| `histology_code` | string | ICD-O-3 morphology | Condition note (SNOMED preferred — see below) |
| `stage_figo` | radio | I/II/III/IV | `Condition.stage.summary.text` |
| `laterality` | radio | 1=Left, 2=Right, 3=Bilateral, 4=Unknown | Condition body site (pending) |
| `primary_surgery` | checkbox | 0/1 | Drives Procedure creation |
| `surgery_date` | date | YYYY-MM-DD | `Procedure.performedDateTime` |
| `surgery_type` | dropdown | see below | `Procedure.code` (SNOMED) |
| `chemo_yn` | checkbox | 0/1 | Drives MedicationStatement (pending) |
| `chemo_start_date` | date | YYYY-MM-DD | MedicationStatement (pending) |
| `chemo_regimen` | text | free text | MedicationStatement (pending) |
| `recurrence_date` | date | YYYY-MM-DD | Second Condition (pending) |
| `status` | radio | 1=Alive, 2=Deceased, 3=Lost | `Patient.deceasedBoolean` / extension |
| `notes` | text | free text | DocumentReference (for Comprehend NLP) |

## SNOMED CT concept agreement required

**Condition code** — currently mapped to `254892004` (Carcinoma of ovary).
Needs clinical review: should this be more granular per histology_code? e.g.:
- 8441/3 Serous adenocarcinoma → `413448000` High grade serous carcinoma of ovary
- 8460/3 Papillary serous → `413448000` (same or separate?)
- 8380/3 Endometrioid → `254895002` Endometrioid carcinoma of ovary

**Procedure codes** — currently mapped as:
| surgery_type | SNOMED | Display |
|---|---|---|
| tah_bso | 116140006 | Total abdominal hysterectomy with bilateral salpingo-oophorectomy |
| cytoreduction | 315024004 | Cytoreductive surgery |
| staging | 174432000 | Staging laparotomy for gynaecological cancer |
| laparoscopy | 387714009 | Laparoscopic staging for gynaecological cancer |

## Resources not yet mapped (backlog)
- `ethnicity` → Patient extension (NZ ethnicity extension URL TBC)
- `laterality` → `Condition.bodySite` SNOMED codes
- `chemo_*` → `MedicationStatement` or `CarePlan`
- `recurrence_date` → second `Condition` with `onsetDateTime`
- `status = deceased` → `Patient.deceasedBoolean = true`
- `notes` → `DocumentReference` for Comprehend Medical NLP processing
