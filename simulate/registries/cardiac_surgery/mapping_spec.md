# Cardiac Surgery Registry — field-to-FHIR mapping spec

**Status: DRAFT — requires clinical team sign-off before production use.**

## REDCap fields

| Field | Type | Values | FHIR target |
|---|---|---|---|
| `record_id` | int | unique | Resource ID suffix |
| `nhi_number` | string | NHI (old format) | `Patient.identifier` (system: NHI) |
| `dob` | date | YYYY-MM-DD | `Patient.birthDate` |
| `sex` | radio | 1=Female, 2=Male | `Patient.gender` |
| `operation_date` | date | YYYY-MM-DD | `Procedure.performedDateTime` |
| `procedure_type` | dropdown | cabg/avr/mvr/tavr/bentall | `Procedure.code` (SNOMED) |
| `procedure_code` | string | SNOMED (from REDCap) | Informational — mapping uses `procedure_type` |
| `surgeon_id` | string | HPI practitioner number | `Procedure.performer` (pending) |
| `priority` | radio | 1=Elective, 2=Urgent, 3=Emergency, 4=Salvage | `Procedure.extension` (pending) |
| `euroscore2` | decimal | % | `Observation` (LOINC 89243-0) |
| `bypass_time_mins` | integer | minutes | `Observation` (LOINC TBC) |
| `los_days` | integer | days | `Observation` (LOINC 89242-2) |
| `mortality_30d` | checkbox | 0/1 | `Observation` (pending) |
| `readmission_30d` | checkbox | 0/1 | `Observation` (pending) |
| `discharge_destination` | radio | 1=Home, 2=Rehab, 3=Residential, 4=Deceased | `Encounter.hospitalization.dischargeDisposition` (pending) |
| `complications` | text | free text | `DocumentReference` for Comprehend NLP |

## SNOMED CT procedure codes

| procedure_type | SNOMED | Display |
|---|---|---|
| cabg | 232717009 | Coronary artery bypass graft |
| avr | 65205006 | Aortic valve replacement |
| mvr | 71371000 | Mitral valve replacement |
| tavr | 450566007 | Transcatheter aortic valve replacement |
| bentall | 174802006 | Bentall procedure |

## Resources not yet mapped (backlog)
- `surgeon_id` → `Procedure.performer` referencing a `Practitioner` resource (requires HPI lookup)
- `priority` → Procedure extension or `ServiceRequest.priority`
- `bypass_time_mins` → `Observation` (LOINC code TBC with clinical team)
- `mortality_30d`, `readmission_30d` → `Observation` with boolean value
- `discharge_destination` → `Encounter.hospitalization.dischargeDisposition`
- `complications` → `DocumentReference` for Comprehend Medical NLP processing
