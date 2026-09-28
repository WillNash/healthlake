"""Shared helpers for constructing FHIR R4 resources."""

NHI_SYSTEM = "https://standards.digital.health.nz/ns/nhi-id"
SNOMED_SYSTEM = "http://snomed.info/sct"
LOINC_SYSTEM = "http://loinc.org"

_SEX_MAP = {
    "0": "unknown",
    "1": "female",
    "2": "male",
    "f": "female",
    "m": "male",
    "female": "female",
    "male": "male",
}


def patient(nhi: str, dob: str = None, sex_code: str = None) -> dict:
    r = {
        "resourceType": "Patient",
        "id": f"patient-{nhi.upper()}",
        "identifier": [{"system": NHI_SYSTEM, "value": nhi.upper()}],
    }
    if dob:
        r["birthDate"] = dob
    if sex_code is not None:
        r["gender"] = _SEX_MAP.get(sex_code.strip().lower(), "unknown")
    return r


def condition(
    resource_id: str,
    nhi: str,
    code: str,
    system: str,
    display: str,
    onset_date: str = None,
    stage_text: str = None,
) -> dict:
    r = {
        "resourceType": "Condition",
        "id": resource_id,
        "subject": {"reference": f"Patient/patient-{nhi.upper()}"},
        "clinicalStatus": {
            "coding": [{
                "system": "http://terminology.hl7.org/CodeSystem/condition-clinical",
                "code": "active",
            }]
        },
        "verificationStatus": {
            "coding": [{
                "system": "http://terminology.hl7.org/CodeSystem/condition-ver-status",
                "code": "confirmed",
            }]
        },
        "code": {"coding": [{"system": system, "code": code, "display": display}]},
    }
    if onset_date:
        r["onsetDateTime"] = onset_date
    if stage_text:
        r["stage"] = [{"summary": {"text": stage_text}}]
    return r


def procedure(
    resource_id: str,
    nhi: str,
    code: str,
    display: str,
    performed_date: str = None,
    note_text: str = None,
) -> dict:
    r = {
        "resourceType": "Procedure",
        "id": resource_id,
        "subject": {"reference": f"Patient/patient-{nhi.upper()}"},
        "status": "completed",
        "code": {"coding": [{"system": SNOMED_SYSTEM, "code": code, "display": display}]},
    }
    if performed_date:
        r["performedDateTime"] = performed_date
    if note_text:
        r["note"] = [{"text": note_text}]
    return r


def observation(
    resource_id: str,
    nhi: str,
    loinc_code: str,
    display: str,
    value: float,
    unit: str,
    unit_code: str,
    effective_date: str = None,
) -> dict:
    r = {
        "resourceType": "Observation",
        "id": resource_id,
        "status": "final",
        "subject": {"reference": f"Patient/patient-{nhi.upper()}"},
        "code": {"coding": [{"system": LOINC_SYSTEM, "code": loinc_code, "display": display}]},
        "valueQuantity": {
            "value": value,
            "unit": unit,
            "system": "http://unitsofmeasure.org",
            "code": unit_code,
        },
    }
    if effective_date:
        r["effectiveDateTime"] = effective_date
    return r
