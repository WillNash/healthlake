"""
REDCap → FHIR R4 mapping for the NZ Gynaecological Oncology Registry (ovarian cancer cohort).

SNOMED CT concept agreement with the clinical team is the prerequisite for using this
mapping in production. The codes below are placeholders that must be confirmed by the
relevant clinical team and mapped via the NZ SNOMED CT terminology service before
data is loaded into HealthLake.
"""

from fhir_builder import condition, patient, procedure, SNOMED_SYSTEM

# surgery_type field values → (SNOMED code, display)
# Confirm these mappings with the clinical team before production use.
_SURGERY_SNOMED = {
    "tah_bso": ("116140006", "Total abdominal hysterectomy with bilateral salpingo-oophorectomy"),
    "cytoreduction": ("315024004", "Cytoreductive surgery"),
    "staging": ("174432000", "Staging laparotomy for gynaecological cancer"),
    "laparoscopy": ("387714009", "Laparoscopic staging for gynaecological cancer"),
    "debulking": ("315024004", "Cytoreductive surgery"),
}

_DEFAULT_SURGERY = ("387714009", "Surgical procedure for ovarian cancer")


def map_row(row: dict) -> list:
    record_id = row.get("record_id", "").strip()
    nhi = row.get("nhi_number", "").strip()
    if not record_id or not nhi:
        return []

    resources = []

    resources.append(patient(
        nhi=nhi,
        dob=row.get("dob", "").strip() or None,
        sex_code=row.get("sex", "").strip() or None,
    ))

    diagnosis_date = row.get("diagnosis_date", "").strip() or None
    stage = row.get("stage_figo", "").strip()
    if diagnosis_date or stage:
        resources.append(condition(
            resource_id=f"condition-oc-{record_id}",
            nhi=nhi,
            code="254892004",
            system=SNOMED_SYSTEM,
            display="Carcinoma of ovary",
            onset_date=diagnosis_date,
            stage_text=f"FIGO Stage {stage}" if stage else None,
        ))

    surgery_date = row.get("surgery_date", "").strip() or None
    surgery_type = (
        row.get("surgery_type", "").strip().lower().replace(" ", "_").replace("-", "_")
    )
    if surgery_date or surgery_type:
        code, display = _SURGERY_SNOMED.get(surgery_type, _DEFAULT_SURGERY)
        resources.append(procedure(
            resource_id=f"procedure-oc-{record_id}",
            nhi=nhi,
            code=code,
            display=display,
            performed_date=surgery_date,
        ))

    return resources
