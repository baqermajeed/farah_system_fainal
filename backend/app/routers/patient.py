from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from datetime import datetime, timezone
from typing import List, Optional
import asyncio

from beanie import PydanticObjectId as OID

from app.schemas import PatientOut, PatientAppointmentsOut, AppointmentOut, NoteOut, GalleryOut, DoctorOut, PatientUpdate
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services import patient_service
from app.models import Patient, Doctor, User
from app.utils.qrcode_gen import ensure_patient_qr
from app.utils.patient_out import build_patient_out, resolve_patient_name
from app.utils.r2_clinic import upload_clinic_image

router = APIRouter(prefix="/patient", tags=["patient"], dependencies=[Depends(require_roles([Role.PATIENT]))])

IMAGE_TYPES = (
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
)


def _appointment_status_for_output(raw_status: str | None) -> str:
    status = (raw_status or "pending").lower().strip()
    if status in {"scheduled", "late"}:
        return "pending"
    if status not in {"pending", "completed", "cancelled"}:
        return "pending"
    return status


async def _family_member_count(user_id: OID) -> int:
    return await Patient.find(Patient.user_id == user_id).count()


async def _resolve_active_patient(
    current: User,
    patient_id: Optional[str] = None,
) -> tuple[Patient, int]:
    """Resolve which family profile is active for this session."""
    family_count = await _family_member_count(current.id)

    if patient_id:
        try:
            patient = await Patient.get(OID(patient_id))
        except Exception:
            patient = None
        if not patient or patient.user_id != current.id:
            raise HTTPException(status_code=403, detail="Patient profile not found or forbidden")
        return patient, family_count

    patients = await Patient.find(Patient.user_id == current.id).sort(-Patient.created_at).to_list()
    if not patients:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    if len(patients) == 1:
        return patients[0], family_count

    primary = next((p for p in patients if getattr(p, "is_primary", False)), None)
    if primary:
        return primary, family_count

    raise HTTPException(
        status_code=400,
        detail="patient_id مطلوب عند وجود أكثر من فرد في العائلة",
    )


@router.get("/profiles", response_model=List[PatientOut])
async def list_my_profiles(current=Depends(get_current_user)):
    """قائمة أفراد العائلة المرتبطين بنفس رقم الهاتف."""
    patients = await Patient.find(Patient.user_id == current.id).sort(-Patient.created_at).to_list()
    if not patients:
        raise HTTPException(status_code=404, detail="Patient profile not found")

    family_count = len(patients)
    out: List[PatientOut] = []
    for patient in patients:
        if not patient.qr_code_data:
            await ensure_patient_qr(patient)
        out.append(build_patient_out(patient, current, family_member_count=family_count))
    return out


@router.get("/me", response_model=PatientOut)
async def my_profile(
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None, description="معرف الملف الطبي النشط"),
):
    """بيانات ملف مريض نشط (فرد من العائلة)."""
    patient, family_count = await _resolve_active_patient(current, patient_id)
    if not patient.qr_code_data:
        await ensure_patient_qr(patient)
    return build_patient_out(patient, current, family_member_count=family_count)


@router.put("/me", response_model=PatientOut)
async def update_my_profile(
    data: PatientUpdate,
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None, description="معرف الملف الطبي النشط"),
):
    """تحديث بيانات ملف مريض نشط (لا يؤثر على باقي أفراد العائلة)."""
    patient, family_count = await _resolve_active_patient(current, patient_id)

    if data.name is not None:
        patient.name = data.name
    if data.gender is not None:
        patient.gender = data.gender
    if data.age is not None:
        patient.age = data.age
    if data.city is not None:
        patient.city = data.city
    if data.visit_type is not None:
        patient.visit_type = data.visit_type
    if data.consultation_type is not None:
        patient.consultation_type = data.consultation_type
    if data.payment_methods is not None:
        patient.payment_methods = data.payment_methods

    await patient.save()

    if not patient.qr_code_data:
        await ensure_patient_qr(patient)

    return build_patient_out(patient, current, family_member_count=family_count)


@router.post("/me/upload-image", response_model=PatientOut)
async def upload_my_profile_image(
    image: UploadFile = File(...),
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None, description="معرف الملف الطبي النشط"),
):
    """رفع صورة بروفايل للملف الطبي النشط."""
    if image.content_type not in IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"نوع الملف غير مدعوم. الأنواع المدعومة: {', '.join(IMAGE_TYPES)}",
        )

    patient, family_count = await _resolve_active_patient(current, patient_id)
    file_bytes = await image.read()
    image_path = await upload_clinic_image(
        patient_id=str(patient.id),
        folder="profile",
        file_bytes=file_bytes,
        content_type=image.content_type,
        name_hint=patient.name or current.name,
    )
    patient.imageUrl = image_path
    await patient.save()
    return build_patient_out(patient, current, family_member_count=family_count)


@router.get("/doctor", response_model=DoctorOut)
async def my_doctor(
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None),
):
    """معلومات الطبيب المرتبط بالملف الطبي النشط."""
    patient, _ = await _resolve_active_patient(current, patient_id)

    if not patient.doctor_ids:
        raise HTTPException(status_code=404, detail="No doctor assigned")

    doctor = await Doctor.get(patient.doctor_ids[0])
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")

    user = await User.get(doctor.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Doctor user not found")

    return DoctorOut(
        id=str(doctor.id),
        user_id=str(doctor.user_id),
        name=user.name,
        phone=user.phone,
        imageUrl=user.imageUrl,
    )


@router.get("/doctors", response_model=List[DoctorOut])
async def my_doctors(
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None),
):
    """قائمة الأطباء المرتبطين بالملف الطبي النشط."""
    from beanie.operators import In

    patient, _ = await _resolve_active_patient(current, patient_id)

    if not patient.doctor_ids:
        return []

    doctors = await Doctor.find(In(Doctor.id, patient.doctor_ids)).to_list()
    user_ids = list({d.user_id for d in doctors if d.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    out: List[DoctorOut] = []
    for d in doctors:
        u = user_map.get(d.user_id)
        if u:
            out.append(DoctorOut(
                id=str(d.id),
                user_id=str(d.user_id),
                name=u.name,
                phone=u.phone,
                imageUrl=u.imageUrl,
            ))
    return out


@router.get("/appointments", response_model=PatientAppointmentsOut)
async def my_appointments(
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None),
):
    """مواعيد الملف الطبي النشط."""
    patient, _ = await _resolve_active_patient(current, patient_id)

    primary, secondary = await patient_service.list_patient_appointments_grouped(
        patient_id=str(patient.id)
    )

    async def build_appointment_out(a):
        patient_name = None
        try:
            apt_patient = await Patient.get(a.patient_id)
            if apt_patient:
                user = await User.get(apt_patient.user_id)
                patient_name = resolve_patient_name(apt_patient, user)
        except Exception:
            pass

        doctor_name = None
        try:
            doctor = await Doctor.get(a.doctor_id)
            if doctor:
                user = await User.get(doctor.user_id)
                if user:
                    doctor_name = user.name
        except Exception:
            pass

        normalized_status = _appointment_status_for_output(getattr(a, "status", None))
        sa = a.scheduled_at if a.scheduled_at else datetime.now(timezone.utc)
        if sa.tzinfo is None:
            sa = sa.replace(tzinfo=timezone.utc)
        else:
            sa = sa.astimezone(timezone.utc)
        is_late = normalized_status == "pending" and sa < datetime.now(timezone.utc)

        return AppointmentOut(
            id=str(a.id),
            patient_id=str(a.patient_id),
            patient_name=patient_name,
            doctor_id=str(a.doctor_id),
            doctor_name=doctor_name,
            scheduled_at=sa.isoformat(),
            note=a.note,
            image_path=a.image_path,
            image_paths=a.image_paths or [],
            status=normalized_status,
            is_late=is_late,
            kind=getattr(a, "kind", "regular") or "regular",
            stage_name=getattr(a, "stage_name", None),
        )

    primary_out = await asyncio.gather(*[build_appointment_out(a) for a in primary])
    secondary_out = await asyncio.gather(*[build_appointment_out(a) for a in secondary])

    return PatientAppointmentsOut(
        primary=primary_out,
        secondary=secondary_out,
    )


@router.get("/notes", response_model=list[NoteOut])
async def my_notes(
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None),
):
    """سجلات علاج الملف الطبي النشط."""
    patient, _ = await _resolve_active_patient(current, patient_id)
    notes = await patient_service.list_notes_for_patient(patient_id=str(patient.id))
    return [NoteOut.model_validate(n) for n in notes]


@router.get("/gallery", response_model=list[GalleryOut])
async def my_gallery(
    current=Depends(get_current_user),
    patient_id: Optional[str] = Query(None),
):
    """معرض صور الملف الطبي النشط."""
    patient, _ = await _resolve_active_patient(current, patient_id)
    gallery = await patient_service.list_gallery_for_patient_public(
        patient_id=str(patient.id),
        skip=0,
        limit=None,
    )
    result = []
    for g in gallery:
        try:
            result.append(
                GalleryOut(
                    id=str(g.id),
                    patient_id=str(g.patient_id),
                    image_path=g.image_path,
                    note=g.note,
                    created_at=g.created_at.isoformat() if g.created_at else datetime.now(timezone.utc).isoformat(),
                )
            )
        except Exception:
            continue
    return result
