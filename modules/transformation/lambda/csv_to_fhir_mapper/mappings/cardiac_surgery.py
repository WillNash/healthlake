"""
REDCap → FHIR R4 mapping for the NZ Cardiac Surgery Registry.

SNOMED CT concept agreement with the clinical team is the prerequisite for using this
mapping in production. The codes below are placeholders that must be confirmed before
data is loaded into HealthLake.
"""

from fhir_builder import observation, patient, procedure, SNOMED_SYSTEM

# procedure_type field values → (SNOMED code, display)
_PROCEDURE_SNOMED = {
    "cabg": ("232717009", "Coronary artery bypass graft"),
    "avr": ("65205006", "Aortic valve replacement"),
    "mvr": ("71371000", "Mitral valve replacement"),
    "tavr": ("450566007", "Transcatheter aortic valve replacement"),
    "bentall": ("174802006", "Bentall procedure"),
    "repair": ("64915003", "Operative procedure on heart"),
}

_DEFAULT_PROCEDURE = ("64915003", "Cardiac surgical procedure")


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

    op_date = row.get("operation_date", "").strip() or None
    proc_type = row.get("procedure_type", "").strip().lower()
    code, display = _PROCEDURE_SNOMED.get(proc_type, _DEFAULT_PROCEDURE)

    resources.append(procedure(
        resource_id=f"procedure-cs-{record_id}",
        nhi=nhi,
        code=code,
        display=display,
        performed_date=op_date,
    ))

    ref_date = op_date or "2026-01-01"

    euroscore = row.get("euroscore2", "").strip()
    if euroscore:
        try:
            resources.append(observation(
                resource_id=f"observation-euroscore-{record_id}",
                nhi=nhi,
                loinc_code="89243-0",
                display="EuroSCORE II predicted operative mortality rate",
                value=float(euroscore),
                unit="%",
                unit_code="%",
                effective_date=ref_date,
            ))
        except ValueError:
            pass

    los = row.get("los_days", "").strip()
    if los:
        try:
            resources.append(observation(
                resource_id=f"observation-los-{record_id}",
                nhi=nhi,
                loinc_code="89242-2",
                display="Hospital length of stay",
                value=float(los),
                unit="d",
                unit_code="d",
                effective_date=ref_date,
            ))
        except ValueError:
            pass

    return resources
