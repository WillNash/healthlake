# HEARTLAND HF Registry — Mapping Specification

Source: https://github.com/vickymuller-md/heartland-redcap-template  
Protocol: HEARTLAND v3.3 (rural heart failure GDMT optimisation, US)

This registry uses REDCap **repeating instruments**. A single patient export
contains one baseline row (empty `redcap_repeat_instrument`) and up to 12
monthly follow-up rows (`redcap_repeat_instrument = monthly_followup`).

---

## Forms

| REDCap form | Rows | FHIR output |
|---|---|---|
| enrollment | baseline row | Patient |
| baseline | baseline row | Condition, Observation (LVEF, eGFR, BNP) |
| gdmt_status | baseline row | **TODO** MedicationStatement ×4 |
| monthly_followup | repeat rows | Observation ×8 per visit + KCCQ-12 |
| outcomes_12mo | baseline row | **TODO** Observation (KCCQ-12 at 12mo) |

---

## Patient

| REDCap field | FHIR path | Notes |
|---|---|---|
| `record_id` | `Patient.id`, `Patient.identifier.value` | System: `urn:heartland:registry:record-id` |
| `sex` | `Patient.gender` | 1=male, 2=female, 3=other |
| `age` | — | Age in years, not mapped (no DOB available) |
| `race___5` | — | TODO: map to US Core race extension |
| `ethnicity` | — | TODO: map to US Core ethnicity extension |

---

## Condition — Heart Failure

| REDCap field | FHIR path | Value |
|---|---|---|
| — | `Condition.code.coding[0].system` | `http://snomed.info/sct` |
| — | `Condition.code.coding[0].code` | `84114007` ⚠️ placeholder |
| — | `Condition.code.coding[0].display` | `Heart failure` |
| `enr_date` | `Condition.onsetDateTime` | |
| `bl_lvef_category` | `Condition.stage[0].summary.text` | HFrEF / HFmrEF / HFpEF label |

---

## Observations — Baseline

| REDCap field | LOINC | Display | Unit |
|---|---|---|---|
| `bl_lvef_pct` | 8834-4 ⚠️ | Left ventricular Ejection fraction | % |
| `bl_egfr` | 33914-3 ⚠️ | Glomerular filtration rate/1.73 sq M.predicted | mL/min/1.73m2 |
| `bl_np_value` | 42637-9 (BNP) or 33762-6 (NT-proBNP) ⚠️ | Natriuretic peptide | pg/mL |

---

## Observations — Monthly Follow-up

| REDCap field | LOINC | Display | Unit |
|---|---|---|---|
| `mo_sbp` | 8480-6 ⚠️ | Systolic blood pressure | mmHg |
| `mo_dbp` | 8462-4 ⚠️ | Diastolic blood pressure | mmHg |
| `mo_hr` | 8867-4 ⚠️ | Heart rate | bpm |
| `mo_spo2` | 59408-5 ⚠️ | Oxygen saturation by pulse oximetry | % |
| `mo_weight_lb` | 29463-7 ⚠️ | Body weight | [lb_av] |
| `mo_egfr` | 33914-3 ⚠️ | Glomerular filtration rate/1.73 sq M.predicted | mL/min/1.73m2 |
| `mo_k` | 2823-3 ⚠️ | Potassium in Serum or Plasma | mEq/L |
| `mo_bnp` | 42637-9 ⚠️ | BNP [Mass/volume] in Blood | pg/mL |
| `mo_kccq12_score` | 86923-0 ⚠️ | KCCQ-12 summary score | {score} |

---

## Known Gaps / TODO

- **MedicationStatement**: GDMT drug classes (ARNI/ACEi/ARB, beta-blocker, MRA, SGLT2i) are not yet mapped. `fhir_builder.py` needs a `medication_statement()` helper.
- **US Core race/ethnicity extensions**: `race___5` and `ethnicity` fields not mapped.
- **12-month KCCQ-12**: `out_kccq12_12mo` (outcomes form) not yet mapped.
- **Outcome observations**: HF hospitalisation counts, days alive out of hospital not mapped.
- **Body weight unit**: HEARTLAND records weight in lb (`mo_weight_lb`). Consider converting to kg for UCUM conformance or confirming [lb_av] is acceptable.

---

## ⚠️ All LOINC and SNOMED codes are placeholders

This is a demonstration mapping using a US heart failure dataset (not NZ clinical data). All codes require review before use in any clinical or research context.
