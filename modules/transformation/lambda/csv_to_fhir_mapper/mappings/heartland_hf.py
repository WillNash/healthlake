"""
REDCap → FHIR R4 mapping for the HEARTLAND Heart Failure Registry.

Source: https://github.com/vickymuller-md/heartland-redcap-template
Protocol: HEARTLAND v3.3 (rural heart failure GDMT optimisation)

The HEARTLAND export uses REDCap repeating instruments. Each patient
has one baseline row (redcap_repeat_instrument is empty) containing
enrollment, baseline risk variables, GDMT status, and 12-month outcomes,
plus up to 12 monthly follow-up rows (redcap_repeat_instrument =
"monthly_followup").

SNOMED CT and LOINC codes are placeholders pending clinical review.
MedicationStatement resources for GDMT classes are a known gap — marked TODO.
"""

from fhir_builder import condition, observation, patient, LOINC_SYSTEM, SNOMED_SYSTEM

_HF_SNOMED = "84114007"
_HF_DISPLAY = "Heart failure"

_LVEF_CATEGORY = {
    "1": "HFrEF (LVEF ≤40%)",
    "2": "HFmrEF (LVEF 41–49%)",
    "3": "HFpEF (LVEF ≥50%)",
}

# HEARTLAND sex coding: 1=Male, 2=Female, 3=Other (differs from NZ NHI convention)
_SEX_MAP = {
    "1": "male",
    "2": "female",
    "3": "other",
}

# bl_np_type: 1=BNP, 2=NT-proBNP
_NP_LOINC = {
    "1": ("42637-9", "BNP [Mass/volume] in Blood"),
    "2": ("33762-6", "NT-proBNP [Mass/volume] in Blood"),
}

# Monthly follow-up vitals: (field, loinc_code, display, unit, ucum_code)
_MONTHLY_VITALS = [
    ("mo_sbp",        "8480-6",  "Systolic blood pressure",                           "mmHg",          "mm[Hg]"),
    ("mo_dbp",        "8462-4",  "Diastolic blood pressure",                          "mmHg",          "mm[Hg]"),
    ("mo_hr",         "8867-4",  "Heart rate",                                        "bpm",           "/min"),
    ("mo_spo2",       "59408-5", "Oxygen saturation by pulse oximetry",               "%",             "%"),
    ("mo_weight_lb",  "29463-7", "Body weight",                                       "[lb_av]",       "[lb_av]"),
    ("mo_egfr",       "33914-3", "Glomerular filtration rate/1.73 sq M.predicted",    "mL/min/1.73m2", "mL/min/{1.73_m2}"),
    ("mo_k",          "2823-3",  "Potassium [Moles/volume] in Serum or Plasma",       "mEq/L",         "meq/L"),
    ("mo_bnp",        "42637-9", "BNP [Mass/volume] in Blood",                        "pg/mL",         "pg/mL"),
]


def map_row(row: dict) -> list:
    record_id = row.get("record_id", "").strip()
    if not record_id:
        return []

    repeat = row.get("redcap_repeat_instrument", "").strip()

    if not repeat:
        if not row.get("enr_date", "").strip():
            return []
        return _map_baseline(record_id, row)
    if repeat == "monthly_followup":
        return _map_monthly(record_id, row)
    return []


def _map_baseline(record_id: str, row: dict) -> list:
    resources = []

    # Patient — use record_id as identifier; no NHI in this US dataset
    sex_raw = row.get("sex", "").strip()
    p = patient(
        nhi=record_id,
        identifier_system="urn:heartland:registry:record-id",
    )
    p["gender"] = _SEX_MAP.get(sex_raw, "unknown")
    resources.append(p)

    enr_date = row.get("enr_date", "").strip() or None
    lvef_cat = row.get("bl_lvef_category", "").strip()

    resources.append(condition(
        resource_id=f"condition-hf-{record_id}",
        nhi=record_id,
        code=_HF_SNOMED,
        system=SNOMED_SYSTEM,
        display=_HF_DISPLAY,
        onset_date=enr_date,
        stage_text=_LVEF_CATEGORY.get(lvef_cat),
    ))

    ref_date = enr_date or "2026-01-01"

    lvef = row.get("bl_lvef_pct", "").strip()
    if lvef:
        try:
            resources.append(observation(
                resource_id=f"observation-lvef-{record_id}",
                nhi=record_id,
                loinc_code="8834-4",
                display="Left ventricular Ejection fraction",
                value=float(lvef),
                unit="%",
                unit_code="%",
                effective_date=ref_date,
            ))
        except ValueError:
            pass

    egfr = row.get("bl_egfr", "").strip()
    if egfr:
        try:
            resources.append(observation(
                resource_id=f"observation-egfr-bl-{record_id}",
                nhi=record_id,
                loinc_code="33914-3",
                display="Glomerular filtration rate/1.73 sq M.predicted",
                value=float(egfr),
                unit="mL/min/1.73m2",
                unit_code="mL/min/{1.73_m2}",
                effective_date=ref_date,
            ))
        except ValueError:
            pass

    np_type = row.get("bl_np_type", "").strip()
    np_value = row.get("bl_np_value", "").strip()
    if np_value and np_type in _NP_LOINC:
        loinc_code, loinc_display = _NP_LOINC[np_type]
        try:
            resources.append(observation(
                resource_id=f"observation-np-bl-{record_id}",
                nhi=record_id,
                loinc_code=loinc_code,
                display=loinc_display,
                value=float(np_value),
                unit="pg/mL",
                unit_code="pg/mL",
                effective_date=ref_date,
            ))
        except ValueError:
            pass

    # TODO: MedicationStatement resources for each GDMT class
    # (gdmt_arni_acei_arb_drug, gdmt_bb_drug, gdmt_mra_drug, gdmt_sglt2_drug)
    # fhir_builder does not yet have a medication_statement() helper.

    return resources


def _map_monthly(record_id: str, row: dict) -> list:
    resources = []
    instance = row.get("redcap_repeat_instance", "").strip()
    suffix = f"{record_id}-mo{instance}"
    visit_date = row.get("mo_date", "").strip() or None

    for field, loinc, display, unit, unit_code in _MONTHLY_VITALS:
        val = row.get(field, "").strip()
        if not val:
            continue
        try:
            resources.append(observation(
                resource_id=f"observation-{field.replace('_', '-')}-{suffix}",
                nhi=record_id,
                loinc_code=loinc,
                display=display,
                value=float(val),
                unit=unit,
                unit_code=unit_code,
                effective_date=visit_date,
            ))
        except ValueError:
            pass

    kccq = row.get("mo_kccq12_score", "").strip()
    if kccq:
        try:
            resources.append(observation(
                resource_id=f"observation-kccq12-{suffix}",
                nhi=record_id,
                loinc_code="86923-0",
                display="Kansas City Cardiomyopathy Questionnaire 12-item score",
                value=float(kccq),
                unit="{score}",
                unit_code="{score}",
                effective_date=visit_date,
            ))
        except ValueError:
            pass

    return resources
