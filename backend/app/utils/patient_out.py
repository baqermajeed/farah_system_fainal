"""Build PatientOut and resolve per-profile identity fields (family-aware)."""

from __future__ import annotations

from datetime import datetime
from typing import Dict, Optional

from app.models import Patient, User
from app.schemas import DoctorPatientProfileOut, PatientOut
from app.utils.patient_profile import build_doctor_profile_map, get_doctor_profile


def resolve_patient_identity(patient: Patient, user: User | None) -> dict:
    """Return display fields for one family member; Patient fields take precedence."""
    return {
        "name": patient.name if patient.name is not None else (user.name if user else None),
        "gender": patient.gender if patient.gender is not None else (user.gender if user else None),
        "age": patient.age if patient.age is not None else (user.age if user else None),
        "city": patient.city if patient.city is not None else (user.city if user else None),
        "phone": user.phone if user else "",
        "imageUrl": patient.imageUrl if patient.imageUrl is not None else (user.imageUrl if user else None),
    }


def resolve_patient_identity_from_docs(patient_doc: dict, user_doc: dict) -> dict:
    """Aggregation-friendly variant of resolve_patient_identity."""
    return {
        "name": patient_doc.get("name") if patient_doc.get("name") is not None else user_doc.get("name"),
        "gender": patient_doc.get("gender") if patient_doc.get("gender") is not None else user_doc.get("gender"),
        "age": patient_doc.get("age") if patient_doc.get("age") is not None else user_doc.get("age"),
        "city": patient_doc.get("city") if patient_doc.get("city") is not None else user_doc.get("city"),
        "phone": user_doc.get("phone", ""),
        "imageUrl": patient_doc.get("imageUrl")
        if patient_doc.get("imageUrl") is not None
        else user_doc.get("imageUrl"),
    }


def resolve_patient_name(patient: Patient, user: User | None = None) -> str | None:
    identity = resolve_patient_identity(patient, user)
    return identity.get("name")


def build_patient_out(
    patient: Patient,
    user: User | None,
    *,
    doctor_id: str | None = None,
    family_member_count: int | None = None,
) -> PatientOut:
    identity = resolve_patient_identity(patient, user)
    doctor_profiles = build_doctor_profile_map(patient, doctor_id=doctor_id)

    treatment_type: str | None = patient.treatment_type
    payment_methods = getattr(patient, "payment_methods", None)

    if doctor_id:
        doctor_profile = get_doctor_profile(patient, doctor_id=doctor_id, profiles=doctor_profiles)
        treatment_type = doctor_profile.treatment_type if doctor_profile else None
        payment_methods = doctor_profile.payment_methods if doctor_profile else None
    elif not treatment_type and patient.doctor_profiles:
        for profile in patient.doctor_profiles.values():
            if profile and profile.treatment_type:
                treatment_type = profile.treatment_type
                break

    created_at = patient.created_at.isoformat() if getattr(patient, "created_at", None) else None

    return PatientOut(
        id=str(patient.id),
        user_id=str(patient.user_id),
        name=identity["name"],
        phone=identity["phone"],
        gender=identity["gender"],
        age=identity["age"],
        city=identity["city"],
        treatment_type=treatment_type,
        visit_type=getattr(patient, "visit_type", None),
        consultation_type=getattr(patient, "consultation_type", None),
        payment_methods=payment_methods,
        activity_status=getattr(patient, "activity_status", "pending"),
        is_primary=bool(getattr(patient, "is_primary", True)),
        relationship=getattr(patient, "relationship", None),
        family_member_count=family_member_count,
        doctor_ids=[str(did) for did in patient.doctor_ids],
        doctor_profiles=doctor_profiles,
        qr_code_data=patient.qr_code_data,
        qr_image_path=patient.qr_image_path,
        imageUrl=identity["imageUrl"],
        created_at=created_at,
    )


def _parse_dt(value):
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except Exception:
            return None
    return value


def build_patient_out_from_agg(
    patient_doc: dict,
    user_doc: dict,
    *,
    doctor_id: str | None = None,
) -> PatientOut:
    """Build PatientOut from Mongo aggregation documents."""
    identity = resolve_patient_identity_from_docs(patient_doc, user_doc)

    doctor_profiles_out: Dict[str, DoctorPatientProfileOut] = {}
    doctor_profiles_raw = patient_doc.get("doctor_profiles", {}) or {}

    treatment_type = patient_doc.get("treatment_type")
    payment_methods = patient_doc.get("payment_methods")

    if doctor_id:
        profile = doctor_profiles_raw.get(str(doctor_id))
        if profile:
            doctor_profiles_out[str(doctor_id)] = DoctorPatientProfileOut(
                treatment_type=profile.get("treatment_type"),
                assigned_at=_parse_dt(profile.get("assigned_at")),
                last_action_at=_parse_dt(profile.get("last_action_at")),
                payment_methods=profile.get("payment_methods"),
            )
            treatment_type = profile.get("treatment_type")
            payment_methods = profile.get("payment_methods")

    created_at_raw = patient_doc.get("created_at")
    if isinstance(created_at_raw, datetime):
        created_at = created_at_raw.isoformat()
    elif created_at_raw:
        created_at = str(created_at_raw)
    else:
        created_at = None

    return PatientOut(
        id=str(patient_doc["_id"]),
        user_id=str(patient_doc.get("user_id")),
        name=identity["name"],
        phone=identity["phone"],
        gender=identity["gender"],
        age=identity["age"],
        city=identity["city"],
        treatment_type=treatment_type,
        visit_type=patient_doc.get("visit_type"),
        consultation_type=patient_doc.get("consultation_type"),
        payment_methods=payment_methods,
        activity_status=patient_doc.get("activity_status", "pending"),
        is_primary=bool(patient_doc.get("is_primary", True)),
        relationship=patient_doc.get("relationship"),
        doctor_ids=[str(d) for d in patient_doc.get("doctor_ids", [])],
        doctor_profiles=doctor_profiles_out,
        qr_code_data=patient_doc.get("qr_code_data", ""),
        qr_image_path=patient_doc.get("qr_image_path"),
        imageUrl=identity["imageUrl"],
        created_at=created_at,
    )
