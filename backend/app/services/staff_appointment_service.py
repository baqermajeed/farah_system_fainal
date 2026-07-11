"""قائمة مواعيد الأطباء لموظفي الاستقبال ومركز الاتصالات."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional

from beanie.operators import In as BeanieIn
from fastapi import HTTPException

from app.models import Doctor, Patient, User
from app.schemas import ReceptionAppointmentOut
from app.services import patient_service


def appointment_status_for_output(raw_status: str | None) -> str:
    status = (raw_status or "pending").lower().strip()
    if status in {"scheduled", "late"}:
        return "pending"
    if status not in {"pending", "completed", "cancelled"}:
        return "pending"
    return status


def _parse_date_from(date_from: Optional[str]) -> Optional[datetime]:
    if not date_from:
        return None
    try:
        if "T" in date_from:
            df = datetime.fromisoformat(date_from.replace("Z", "+00:00"))
        else:
            df = datetime.fromisoformat(f"{date_from}T00:00:00+00:00")
        if df.tzinfo is None:
            df = df.replace(tzinfo=timezone.utc)
        return df
    except (ValueError, AttributeError) as exc:
        raise HTTPException(
            status_code=400, detail=f"Invalid date_from format: {date_from}"
        ) from exc


def _parse_date_to(date_to: Optional[str]) -> Optional[datetime]:
    if not date_to:
        return None
    try:
        if "T" in date_to:
            dt = datetime.fromisoformat(date_to.replace("Z", "+00:00"))
        else:
            dt = datetime.fromisoformat(f"{date_to}T23:59:59+00:00")
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except (ValueError, AttributeError) as exc:
        raise HTTPException(
            status_code=400, detail=f"Invalid date_to format: {date_to}"
        ) from exc


async def list_staff_appointments(
    *,
    day: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
) -> List[ReceptionAppointmentOut]:
    """جداول مواعيد جميع المرضى (للاستقبال / مركز الاتصالات)."""
    df = _parse_date_from(date_from)
    dt = _parse_date_to(date_to)

    apps = await patient_service.list_appointments_for_all(
        day=day,
        date_from=df,
        date_to=dt,
        status=status,
        skip=skip,
        limit=limit,
    )

    patient_ids = list({a.patient_id for a in apps})
    doctor_ids = list({a.doctor_id for a in apps})

    patients = (
        await Patient.find(BeanieIn(Patient.id, patient_ids)).to_list()
        if patient_ids
        else []
    )
    doctors = (
        await Doctor.find(BeanieIn(Doctor.id, doctor_ids)).to_list()
        if doctor_ids
        else []
    )

    user_ids = list({p.user_id for p in patients if p.user_id})
    user_ids += [d.user_id for d in doctors if d.user_id]
    user_ids = list(set(user_ids))

    users = await User.find(BeanieIn(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    patient_map = {p.id: p for p in patients}
    doctor_map = {d.id: d for d in doctors}

    out: List[ReceptionAppointmentOut] = []
    for a in apps:
        p = patient_map.get(a.patient_id)
        d = doctor_map.get(a.doctor_id)
        pu = user_map.get(p.user_id) if p else None
        du = user_map.get(d.user_id) if d else None
        normalized_status = appointment_status_for_output(getattr(a, "status", None))
        sa = a.scheduled_at if a.scheduled_at else datetime.now()
        if sa.tzinfo is not None:
            sa = sa.replace(tzinfo=None)
        sa = sa.replace(microsecond=0)
        now_clinic = datetime.now().replace(tzinfo=None, microsecond=0)
        is_late = normalized_status == "pending" and sa < now_clinic

        out.append(
            ReceptionAppointmentOut(
                id=str(a.id),
                patient_id=str(a.patient_id),
                patient_name=pu.name if pu else None,
                patient_phone=pu.phone if pu else None,
                doctor_id=str(a.doctor_id),
                doctor_name=du.name if du else None,
                scheduled_at=sa.isoformat(),
                note=a.note,
                image_path=a.image_path,
                status=normalized_status,
                is_late=is_late,
                kind=getattr(a, "kind", "regular") or "regular",
                stage_name=getattr(a, "stage_name", None),
            )
        )
    return out
