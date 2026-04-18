from typing import Dict, Optional

from app.models import Patient
from app.schemas import DoctorPatientProfileOut


def build_doctor_profile_map(
    patient: Patient, doctor_id: Optional[str] = None
) -> Dict[str, DoctorPatientProfileOut]:
    """Return a mapping of doctor IDs to their per-patient profile data.

    When `doctor_id` is provided, only the matching entry is returned.
    """
    result: Dict[str, DoctorPatientProfileOut] = {}
    doctor_id_filter = str(doctor_id) if doctor_id else None
    for doctor_key, profile in (patient.doctor_profiles or {}).items():
        if not profile:
            continue
        key = str(doctor_key)
        if doctor_id_filter and key != doctor_id_filter:
            continue
        result[key] = DoctorPatientProfileOut(
            treatment_type=profile.treatment_type,
            assigned_at=profile.assigned_at,
            last_action_at=profile.last_action_at,
            payment_methods=getattr(profile, "payment_methods", None),
        )
    return result


def get_doctor_profile(
    patient: Patient,
    doctor_id: str,
    profiles: Optional[Dict[str, DoctorPatientProfileOut]] = None,
) -> DoctorPatientProfileOut | None:
    """Return the profile data for a specific doctor (or None)."""
    profiles = profiles or build_doctor_profile_map(patient, doctor_id=doctor_id)
    if not profiles:
        return None
    return next(iter(profiles.values()))

