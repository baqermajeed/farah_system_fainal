from fastapi import APIRouter, Depends, UploadFile, File, Query, Form, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from datetime import datetime, timezone
import re

from app.schemas import (
    PatientOut,
    DoctorOut,
    GalleryOut,
    GalleryCreate,
    NoteOut,
    AppointmentCreate,
    AppointmentOut,
    AppointmentStatusUpdate,
    PatientUpdate,
    PatientCreate,
    PatientTransferIn,
)
from app.database import get_db
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services import patient_service
from app.services.admin_service import create_patient
from app.services.patient_service import assign_patient_doctors
from app.utils.r2_clinic import upload_clinic_image
from app.models import Doctor, User, Patient
from app.utils.logger import get_logger
from app.utils.patient_profile import build_doctor_profile_map, get_doctor_profile
from beanie.operators import In
from beanie import PydanticObjectId as OID

logger = get_logger("doctor_router")

PHONE_PATTERN = re.compile(r"^07\d{9}$")

IMAGE_TYPES = (
    "image/jpeg",
    "image/png",
    "image/webp",
    # iOS often produces HEIC/HEIF from camera/gallery
    "image/heic",
    "image/heif",
)
MAX_IMAGE_MB = 10

router = APIRouter(prefix="/doctor", tags=["doctor"], dependencies=[Depends(require_roles([Role.DOCTOR]))])


async def _get_patient_user_name(patient_id: str) -> str | None:
    patient = await Patient.get(OID(patient_id))
    if not patient or not patient.user_id:
        return None
    user = await User.get(patient.user_id)
    return user.name if user else None


async def _get_current_doctor_id(current) -> str:
    """
    Helper to resolve the Doctor document for the currently authenticated user.
    """
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    return str(doctor.id)


async def _require_doctor_manager(current) -> str:
    """Ensure current doctor has manager privileges. Returns doctor_id."""
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    if not getattr(doctor, "is_manager", False):
        raise HTTPException(status_code=403, detail="Doctor manager privileges required")
    return str(doctor.id)


def _build_doctor_patient_out(patient: Patient, user: User, doctor_id: str) -> PatientOut:
    doctor_profiles = build_doctor_profile_map(patient, doctor_id=doctor_id)
    doctor_profile = get_doctor_profile(patient, doctor_id=doctor_id, profiles=doctor_profiles)
    
    # نوع العلاج للطبيب الحالي فقط:
    # إذا لم يُحدد الطبيب نوع العلاج لمريضه بعد، نظهر None بدلاً من أخذ نوع علاج طبيب آخر.
    treatment_type = doctor_profile.treatment_type if doctor_profile else None
    
    return PatientOut(
        id=str(patient.id),
        user_id=str(patient.user_id),
        name=user.name,
        phone=user.phone,
        gender=user.gender,
        age=user.age,
        city=user.city,
        treatment_type=treatment_type,
        visit_type=getattr(patient, "visit_type", None),
        doctor_ids=[str(did) for did in patient.doctor_ids],
        doctor_profiles=doctor_profiles,
        qr_code_data=patient.qr_code_data,
        qr_image_path=patient.qr_image_path,
        imageUrl=user.imageUrl,
    )

@router.post("/patients", response_model=PatientOut)
async def add_patient(
    payload: PatientCreate,
    current=Depends(get_current_user),
):
    """إضافة مريض جديد وربطه بالطبيب مباشرة (بدون OTP)."""
    doctor_id = await _get_current_doctor_id(current)
    logger.info(f"Adding patient for doctor_id: {doctor_id}, phone: {payload.phone}")
    if not PHONE_PATTERN.match(payload.phone.strip()):
        raise HTTPException(
            status_code=400,
            detail="رقم الهاتف يجب أن يكون 11 رقم ويبدأ بـ 07",
        )
    
    # التحقق من وجود رقم الهاتف مسبقاً
    existing_user = await User.find_one(User.phone == payload.phone)
    if existing_user:
        # إذا كان المستخدم موجوداً، نحاول ربطه بالطبيب
        patient = await Patient.find_one(Patient.user_id == existing_user.id)
        if patient:
            # ربط المريض بالطبيب
            existing_doctor_ids = [str(did) for did in patient.doctor_ids]
            if doctor_id not in existing_doctor_ids:
                existing_doctor_ids.append(doctor_id)
            await assign_patient_doctors(
                patient_id=str(patient.id),
                doctor_ids=existing_doctor_ids,
                assigned_by_user_id=str(current.id),
            )
            # جلب المريض المحدث
            patient = await Patient.get(patient.id)
            u = existing_user
            return _build_doctor_patient_out(patient, u, doctor_id)
        else:
            raise HTTPException(status_code=400, detail="User exists but is not a patient")
    
    # إنشاء مريض جديد
    patient = await create_patient(
        phone=payload.phone,
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        city=payload.city,
        visit_type=payload.visit_type,
    )
    logger.info(f"Patient created: {patient.id}, user_id: {patient.user_id}")
    
    # ربط المريض بالطبيب
    logger.info(f"Assigning patient {patient.id} to doctor {doctor_id}")
    # Get existing doctors and add new one if not already present
    existing_doctor_ids = [str(did) for did in patient.doctor_ids]
    if doctor_id not in existing_doctor_ids:
        existing_doctor_ids.append(doctor_id)
    patient = await assign_patient_doctors(
        patient_id=str(patient.id),
        doctor_ids=existing_doctor_ids,
        assigned_by_user_id=str(current.id),
    )
    logger.info(f"Patient assigned. doctor_ids: {patient.doctor_ids}")
    
    # جلب المريض المحدث
    patient = await Patient.get(patient.id)
    u = await User.get(patient.user_id)
    logger.info(f"Final patient state - doctor_ids: {patient.doctor_ids}")
    
    return _build_doctor_patient_out(patient, u, doctor_id)


@router.post("/patients/{patient_id}/transfer", response_model=PatientOut)
async def transfer_patient(
    patient_id: str,
    payload: PatientTransferIn,
    current=Depends(get_current_user),
):
    """تحويل مريض إلى طبيب آخر (للطبيب المدير فقط).

    - shared: يبقى المريض مشتركا بين الطبيب المدير والطبيب الهدف.
    - move: يُحذف المريض من قائمة الطبيب المدير ويُضاف للطبيب الهدف (ويبقى أي أطباء آخرين كما هم).
    """
    manager_doctor_id = await _require_doctor_manager(current)

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    # يجب أن يكون المريض ضمن قائمة هذا الطبيب المدير حتى يستطيع تحويله
    if OID(manager_doctor_id) not in (patient.doctor_ids or []):
        raise HTTPException(status_code=403, detail="Not your patient")

    target_id = payload.target_doctor_id
    if not target_id:
        raise HTTPException(status_code=400, detail="target_doctor_id is required")
    if target_id == manager_doctor_id:
        # لا تغيير
        u = await User.get(patient.user_id)
        if not u:
            raise HTTPException(status_code=404, detail="User not found")
        return _build_doctor_patient_out(patient, u, manager_doctor_id)

    # تحقق أن الطبيب الهدف موجود
    target_doctor = await Doctor.get(OID(target_id))
    if not target_doctor:
        raise HTTPException(status_code=404, detail="Target doctor not found")

    current_doctor_ids = [str(did) for did in (patient.doctor_ids or [])]

    if payload.mode == "shared":
        if manager_doctor_id not in current_doctor_ids:
            current_doctor_ids.append(manager_doctor_id)
        if target_id not in current_doctor_ids:
            current_doctor_ids.append(target_id)
    elif payload.mode == "move":
        # إزالة الطبيب المدير من القائمة، وإضافة الطبيب الهدف
        current_doctor_ids = [d for d in current_doctor_ids if d != manager_doctor_id]
        if target_id not in current_doctor_ids:
            current_doctor_ids.append(target_id)
    else:
        raise HTTPException(status_code=400, detail="Invalid transfer mode")

    updated = await assign_patient_doctors(
        patient_id=str(patient.id),
        doctor_ids=current_doctor_ids,
        assigned_by_user_id=str(current.id),
    )

    u = await User.get(updated.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return _build_doctor_patient_out(updated, u, manager_doctor_id)


@router.get("/doctors")
async def list_doctors_for_manager(current=Depends(get_current_user)):
    """قائمة جميع الأطباء مع عدد التحويلات (تعيين المرضى) في هذا اليوم، وتاريخ آخر تحويل.

    - نستخدم حقل doctor_profiles.<doctor_id>.assigned_at الموجود داخل وثيقة المريض،
      ولا نعتمد على أي حدود للـ limit، وبالتالي تُحتسب كل التحويلات.
    - last_transfer_at هو أحدث assigned_at لأي مريض مرتبط بالطبيب.
    """
    _ = await _require_doctor_manager(current)

    from datetime import datetime, timezone, timedelta
    from app.services import patient_service

    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)

    doctors = await Doctor.find({}).to_list()
    user_ids = list({d.user_id for d in doctors if d.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    out = []
    for d in doctors:
        u = user_map.get(d.user_id)
        if not u:
            continue

        doctor_id_str = str(d.id)
        doctor_key = doctor_id_str

        # جلب جميع المرضى المرتبطين بهذا الطبيب (بدون حد للعدد)
        patients = await patient_service.list_doctor_patients(
            doctor_id=doctor_id_str, skip=0, limit=None
        )

        today_transfers = 0
        last_transfer_at: datetime | None = None

        for p in patients:
            profile = (p.doctor_profiles or {}).get(doctor_key)
            if not profile or not getattr(profile, "assigned_at", None):
                continue

            assigned_at = profile.assigned_at
            if assigned_at is None:
                continue

            # ضمان التحويل إلى UTC قبل المقارنة
            if assigned_at.tzinfo is None:
                assigned_utc = assigned_at.replace(tzinfo=timezone.utc)
            else:
                assigned_utc = assigned_at.astimezone(timezone.utc)

            # يحتسب فقط التحويلات التي حدثت في هذا اليوم (يُعاد ضبطها تلقائياً عند 00:00)
            if today_start <= assigned_utc < tomorrow_start:
                today_transfers += 1

            # حفظ أحدث تاريخ تحويل على الإطلاق
            if (last_transfer_at is None) or (assigned_utc > last_transfer_at):
                last_transfer_at = assigned_utc

        doctor_data = {
            "id": doctor_id_str,
            "user_id": str(d.user_id),
            "name": u.name,
            "phone": u.phone,
            "imageUrl": u.imageUrl,
            "today_transfers": today_transfers,
            "last_transfer_at": last_transfer_at.isoformat() if last_transfer_at else None,
        }

        print(
            f"🔍 [Doctor Router] Doctor {u.name}: today_transfers={today_transfers}, last={last_transfer_at}"
        )
        out.append(doctor_data)

    print(f"🔍 [Doctor Router] Returning {len(out)} doctors")
    return out


@router.post("/patients/{patient_id}/upload-image", response_model=PatientOut)
async def upload_patient_profile_image(
    patient_id: str,
    image: UploadFile = File(...),
    current=Depends(get_current_user),
):
    """رفع صورة بروفايل للمريض (للطبيب فقط، ولازم يكون المريض ضمن قائمة مرضاه)."""
    if image.content_type not in IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed types: {', '.join(IMAGE_TYPES)}",
        )

    p = await Patient.get(OID(patient_id))
    if not p:
        raise HTTPException(status_code=404, detail="Patient not found")

    doctor_id = await _get_current_doctor_id(current)
    if OID(doctor_id) not in (p.doctor_ids or []):
        raise HTTPException(status_code=403, detail="Not your patient")

    u = await User.get(p.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    file_bytes = await image.read()
    patient_name_hint = u.name
    image_path = await upload_clinic_image(
        patient_id=str(u.id),  # نخزنها تحت user_id مثل /auth/me/upload-image
        folder="profile",
        file_bytes=file_bytes,
        content_type=image.content_type,
        name_hint=patient_name_hint,
    )

    # upload_clinic_image now returns a direct /media/... URL

    u.imageUrl = image_path
    u.updated_at = datetime.now(timezone.utc)
    await u.save()

    return _build_doctor_patient_out(p, u, doctor_id)

@router.get("/patients", response_model=List[PatientOut])
async def my_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
    current=Depends(get_current_user),
):
    """يعرض المرضى الخاصين بالطبيب (أساسي/ثانوي)."""
    doctor_id = await _get_current_doctor_id(current)
    patients = await patient_service.list_doctor_patients(
        doctor_id, skip=skip, limit=limit
    )
    # Map to PatientOut combining user fields
    out: List[PatientOut] = []
    for p in patients:
        # جلب User مباشرة بدلاً من الاعتماد على p.user
        try:
            u = await User.get(p.user_id)
            if not u:
                print(f"⚠️ Warning: Patient {p.id} has no user (user_id: {p.user_id}), skipping...")
                continue
        except Exception as e:
            print(f"❌ Error fetching user for patient {p.id}: {e}")
            continue
            
        out.append(_build_doctor_patient_out(p, u, doctor_id))
    return out


@router.get("/patients/inactive", response_model=List[PatientOut])
async def my_inactive_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
    current=Depends(get_current_user),
):
    """List patients that became inactive for this doctor."""
    doctor_id = await _get_current_doctor_id(current)
    patients = await patient_service.list_inactive_patients_for_doctor(
        doctor_id, skip=skip, limit=limit
    )
    out: List[PatientOut] = []
    for p in patients:
        try:
            u = await User.get(p.user_id)
            if not u:
                continue
        except Exception:
            continue
        out.append(_build_doctor_patient_out(p, u, doctor_id))
    return out

@router.post("/patients/{patient_id}/treatment", response_model=PatientOut)
async def set_treatment(patient_id: str, treatment_type: str = Query(...), current=Depends(get_current_user)):
    """تحديد نوع العلاج للمريض."""
    doctor_id = await _get_current_doctor_id(current)
    p = await patient_service.set_treatment_type(
        patient_id=patient_id,
        doctor_id=doctor_id,
        treatment_type=treatment_type,
    )
    # جلب User مباشرة بدلاً من الاعتماد على p.user
    u = await User.get(p.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return _build_doctor_patient_out(p, u, doctor_id)

@router.post("/patients/{patient_id}/notes", response_model=NoteOut)
async def add_note(
    patient_id: str,
    note: str | None = Form(None),
    images: List[UploadFile] | None = File(None),
    current=Depends(get_current_user),
):
    """إضافة سجل (ملاحظة) مع صور متعددة اختيارية."""
    image_paths = []
    patient_name_hint = await _get_patient_user_name(patient_id)
    if images:
        for image in images:
            if IMAGE_TYPES and image.content_type not in IMAGE_TYPES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unsupported file type: {image.content_type}. Allowed types: {', '.join(IMAGE_TYPES)}",
                )
            file_bytes = await image.read()
            image_path = await upload_clinic_image(
                patient_id=patient_id,
                folder="notes",
                file_bytes=file_bytes,
                content_type=image.content_type,
                name_hint=patient_name_hint,
            )
            image_paths.append(image_path)
    
    # للتوافق مع البيانات القديمة، نستخدم أول صورة كـ image_path
    image_path = image_paths[0] if image_paths else None
    
    doctor_id = await _get_current_doctor_id(current)
    note_obj = await patient_service.create_note(
        patient_id=patient_id,
        doctor_id=doctor_id,
        note=note,
        image_path=image_path,
        image_paths=image_paths,
    )
    # تحويل TreatmentNote إلى NoteOut يدوياً لضمان قراءة image_paths
    return NoteOut(
        id=str(note_obj.id),
        patient_id=str(note_obj.patient_id),
        doctor_id=str(note_obj.doctor_id),
        note=note_obj.note,
        image_path=note_obj.image_path,
        image_paths=note_obj.image_paths if note_obj.image_paths else None,
        created_at=note_obj.created_at.isoformat() if note_obj.created_at else datetime.now(timezone.utc).isoformat(),
    )

@router.put("/patients/{patient_id}/notes/{note_id}", response_model=NoteOut)
async def update_note(
    patient_id: str,
    note_id: str,
    note: str | None = Form(None),
    images: List[UploadFile] | None = File(None),
    current=Depends(get_current_user),
):
    """تحديث سجل (ملاحظة) مع صور متعددة اختيارية."""
    patient_name_hint = await _get_patient_user_name(patient_id)
    image_paths = []
    if images:
        for image in images:
            if IMAGE_TYPES and image.content_type not in IMAGE_TYPES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unsupported file type: {image.content_type}. Allowed types: {', '.join(IMAGE_TYPES)}",
                )
            file_bytes = await image.read()
            image_path = await upload_clinic_image(
                patient_id=patient_id,
                folder="notes",
                file_bytes=file_bytes,
                content_type=image.content_type,
                name_hint=patient_name_hint,
            )
            image_paths.append(image_path)
    
    doctor_id = await _get_current_doctor_id(current)
    note_obj = await patient_service.update_note(
        patient_id=patient_id,
        note_id=note_id,
        doctor_id=doctor_id,
        note=note,
        image_paths=image_paths if image_paths else None,
    )
    # تحويل TreatmentNote إلى NoteOut يدوياً لضمان قراءة image_paths
    return NoteOut(
        id=str(note_obj.id),
        patient_id=str(note_obj.patient_id),
        doctor_id=str(note_obj.doctor_id),
        note=note_obj.note,
        image_path=note_obj.image_path,
        image_paths=note_obj.image_paths if note_obj.image_paths else None,
        created_at=note_obj.created_at.isoformat() if note_obj.created_at else datetime.now(timezone.utc).isoformat(),
    )

@router.delete("/patients/{patient_id}/notes/{note_id}")
async def delete_note(
    patient_id: str,
    note_id: str,
    current=Depends(get_current_user),
):
    """حذف سجل (ملاحظة)."""
    doctor_id = await _get_current_doctor_id(current)
    await patient_service.delete_note(
        patient_id=patient_id,
        note_id=note_id,
        doctor_id=doctor_id,
    )
    return {"message": "Note deleted successfully"}

@router.post("/patients/{patient_id}/appointments", response_model=AppointmentOut)
async def add_appointment(
    patient_id: str,
    scheduled_at: str = Form(...),
    note: str | None = Form(None),
    images: List[UploadFile] | None = File(None),
    current=Depends(get_current_user),
):
    """إضافة موعد جديد مع ملاحظة واختيار صور متعددة (قسم المواعيد)."""
    image_paths = []
    
    patient_name_hint = await _get_patient_user_name(patient_id)
    if images:
        for image in images:
            if IMAGE_TYPES and image.content_type not in IMAGE_TYPES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Unsupported file type: {image.content_type}. Allowed types: {', '.join(IMAGE_TYPES)}",
                )
            file_bytes = await image.read()
            image_path = await upload_clinic_image(
                patient_id=patient_id,
                folder="appointments",
                file_bytes=file_bytes,
                content_type=image.content_type,
                name_hint=patient_name_hint,
            )
            image_paths.append(image_path)
    
    # للتوافق مع البيانات القديمة، نستخدم أول صورة كـ image_path
    image_path = image_paths[0] if image_paths else None
    
    # نقرأ التاريخ/الوقت كما أرسله الفرونت بدون أي تعديل على المنطقة الزمنية
    # حتى يبقى نفس الوقت الظاهر للمستخدم في الواجهة
    _sa = datetime.fromisoformat(scheduled_at)

    doctor_id = await _get_current_doctor_id(current)
    ap = await patient_service.create_appointment(
        patient_id=patient_id,
        doctor_id=doctor_id,
        scheduled_at=_sa,
        note=note,
        image_path=image_path,
        image_paths=image_paths,
    )
    # تحويل Appointment إلى AppointmentOut يدوياً
    return AppointmentOut(
        id=str(ap.id),
        patient_id=str(ap.patient_id),
        doctor_id=str(ap.doctor_id),
        scheduled_at=ap.scheduled_at.isoformat() if ap.scheduled_at else datetime.now(timezone.utc).isoformat(),
        note=ap.note,
        image_path=ap.image_path,
        image_paths=getattr(ap, 'image_paths', []) if hasattr(ap, 'image_paths') else (([ap.image_path] if ap.image_path else [])),
        status=ap.status,
    )

@router.delete("/patients/{patient_id}/appointments/{appointment_id}")
async def delete_appointment(
    patient_id: str,
    appointment_id: str,
    current=Depends(get_current_user),
):
    """حذف موعد للمريض."""
    doctor_id = await _get_current_doctor_id(current)
    success = await patient_service.delete_appointment(
        appointment_id=appointment_id,
        patient_id=patient_id,
        doctor_id=doctor_id,
    )
    if success:
        return {"message": "Appointment deleted successfully"}
    else:
        raise HTTPException(status_code=500, detail="Failed to delete appointment")

@router.post("/patients/{patient_id}/gallery", response_model=GalleryOut)
async def add_gallery_image(
    patient_id: str,
    note: str | None = Form(None),
    image: UploadFile = File(...),
    current=Depends(get_current_user),
):
    """رفع صورة إلى معرض المريض (قسم المعرض)."""
    doctor_id = await _get_current_doctor_id(current)
    patient_name_hint = await _get_patient_user_name(patient_id)
    if IMAGE_TYPES and image.content_type not in IMAGE_TYPES:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed types: {', '.join(IMAGE_TYPES)}",
        )
    file_bytes = await image.read()
    image_path = await upload_clinic_image(
        patient_id=patient_id,
        folder="gallery",
        file_bytes=file_bytes,
        content_type=image.content_type,
        name_hint=patient_name_hint,
    )
    gi = await patient_service.create_gallery_image(
        patient_id=patient_id,
        uploaded_by_user_id=str(current.id),
        image_path=image_path,
        note=note,
        doctor_id=doctor_id,
    )
    return GalleryOut(
        id=str(gi.id),
        patient_id=str(gi.patient_id),
        image_path=gi.image_path,
        note=gi.note,
        created_at=gi.created_at.isoformat() if gi.created_at else datetime.now(timezone.utc).isoformat(),
    )

@router.get("/appointments", response_model=List[AppointmentOut])
async def list_my_appointments(
    day: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    status: str | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
    current=Depends(get_current_user),
):
    """مواعيدي: اليوم/غدًا/الشهر أو نطاق (مع المتأخرون)."""
    df = datetime.fromisoformat(date_from) if date_from else None
    dt = datetime.fromisoformat(date_to) if date_to else None
    doctor_id = await _get_current_doctor_id(current)
    # نجلب جميع مواعيد الطبيب المطابقة للفلاتر في طلب واحد (بدون حد للـ limit)
    # مع الحفاظ على skip/limit في التوقيع لعدم كسر أي عميل قديم.
    apps = await patient_service.list_appointments_for_doctor(
        doctor_id=doctor_id,
        day=day,
        date_from=df,
        date_to=dt,
        status=status,
        skip=0,
        limit=None,
    )
    result = []
    for a in apps:
        try:
            # جلب بيانات المريض
            patient_name = None
            try:
                patient = await Patient.get(a.patient_id)
                if patient:
                    user = await User.get(patient.user_id)
                    if user:
                        patient_name = user.name
            except Exception as e:
                logger.warning(f"Could not fetch patient name for appointment {a.id}: {e}")
            
            # جلب بيانات الطبيب
            doctor_name = None
            try:
                doctor = await Doctor.get(a.doctor_id)
                if doctor:
                    user = await User.get(doctor.user_id)
                    if user:
                        doctor_name = user.name
            except Exception as e:
                logger.warning(f"Could not fetch doctor name for appointment {a.id}: {e}")
            
            result.append(
                AppointmentOut(
                    id=str(a.id),
                    patient_id=str(a.patient_id),
                    patient_name=patient_name,
                    doctor_id=str(a.doctor_id),
                    doctor_name=doctor_name,
                    scheduled_at=a.scheduled_at.isoformat() if a.scheduled_at else datetime.now(timezone.utc).isoformat(),
                    note=a.note,
                    image_path=a.image_path,
                    image_paths=getattr(a, 'image_paths', []) if hasattr(a, 'image_paths') else (([a.image_path] if a.image_path else [])),
                    status=a.status,
                )
            )
        except Exception as e:
            logger.error(f"Error converting appointment {a.id}: {e}")
            continue
    return result

@router.patch("/patients/{patient_id}", response_model=PatientOut)
async def update_patient(patient_id: int, payload: PatientUpdate, db: AsyncSession = Depends(get_db), current=Depends(get_current_user)):
    """تعديل بيانات مريض من قبل الطبيب (إن كان من مرضاه)."""
    doctor_id = await _get_current_doctor_id(current)
    # patient_service.update_patient_by_doctor يعمل على Mongo/Beanie ويأخذ معرفات كنصوص
    p = await patient_service.update_patient_by_doctor(
        doctor_id=doctor_id,
        patient_id=str(patient_id),
        data=payload,
    )
    u = await User.get(p.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return _build_doctor_patient_out(p, u, doctor_id)

@router.delete("/patients/{patient_id}", status_code=204)
async def delete_patient(patient_id: int, db: AsyncSession = Depends(get_db), current=Depends(get_current_user)):
    """حذف مريض من قبل الطبيب (إن كان من مرضاه)."""
    doctor_id = await _get_current_doctor_id(current)
    await patient_service.delete_patient(
        actor_role=Role.DOCTOR,
        patient_id=str(patient_id),
        actor_doctor_id=doctor_id,
    )
    return None

@router.get("/patients/{patient_id}/notes", response_model=List[NoteOut])
async def list_notes(
    patient_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current=Depends(get_current_user),
):
    """قائمة السجلات للمريض (القسم الأول)."""
    doctor_id = await _get_current_doctor_id(current)
    notes = await patient_service.list_notes_for_patient(
        patient_id=patient_id, skip=skip, limit=limit, doctor_id=doctor_id
    )
    result = []
    for n in notes:
        result.append(
            NoteOut(
                id=str(n.id),
                patient_id=str(n.patient_id),
                doctor_id=str(n.doctor_id),
                note=n.note,
                image_path=n.image_path,
                image_paths=n.image_paths if n.image_paths else None,
                created_at=n.created_at.isoformat() if n.created_at else datetime.now(timezone.utc).isoformat(),
            )
        )
    return result

@router.get("/patients/{patient_id}/appointments", response_model=List[AppointmentOut])
async def list_patient_appointments(
    patient_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current=Depends(get_current_user),
):
    """قائمة مواعيد المريض."""
    doctor_id = await _get_current_doctor_id(current)
    appointments = await patient_service.list_patient_appointments_for_doctor(
        patient_id=patient_id, doctor_id=doctor_id, skip=skip, limit=limit
    )
    result = []
    for ap in appointments:
        try:
            result.append(
                AppointmentOut(
                    id=str(ap.id),
                    patient_id=str(ap.patient_id),
                    doctor_id=str(ap.doctor_id),
                    scheduled_at=ap.scheduled_at.isoformat() if ap.scheduled_at else datetime.now(timezone.utc).isoformat(),
                    note=ap.note,
                    image_path=ap.image_path,
                    image_paths=getattr(ap, 'image_paths', []) if hasattr(ap, 'image_paths') else (([ap.image_path] if ap.image_path else [])),
                    status=ap.status,
                )
            )
        except Exception as e:
            logger.error(f"Error converting appointment {ap.id}: {e}")
            continue
    return result

@router.get("/patients/{patient_id}/gallery", response_model=List[GalleryOut])
async def list_gallery(
    patient_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current=Depends(get_current_user),
):
    """قائمة صور المعرض للمريض (القسم الثالث).

    - الطبيب يشاهد الصور التي قام هو برفعها للمريض.
    - بالإضافة إلى الصور التي رفعها موظفو الاستقبال لهذا المريض.
    - لا يشاهد الصور التي رفعها أطباء آخرون لنفس المريض.
    """
    doctor_id = await _get_current_doctor_id(current)
    gallery = await patient_service.list_gallery_for_doctor_view(
        patient_id=patient_id, doctor_id=doctor_id, skip=skip, limit=limit
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
        except Exception as e:
            logger.error(f"Error converting gallery image {g.id}: {e}")
            # Skip this image if there's an error
            continue
    return result

@router.delete("/patients/{patient_id}/gallery/{gallery_image_id}")
async def delete_gallery_image(
    patient_id: str,
    gallery_image_id: str,
    current=Depends(get_current_user),
):
    """حذف صورة من معرض المريض."""
    doctor_id = await _get_current_doctor_id(current)
    success = await patient_service.delete_gallery_image(
        gallery_image_id=gallery_image_id,
        patient_id=patient_id,
        doctor_id=doctor_id,
    )
    if success:
        return {"message": "Gallery image deleted successfully"}
    else:
        raise HTTPException(status_code=500, detail="Failed to delete gallery image")

@router.patch("/patients/{patient_id}/appointments/{appointment_id}/status", response_model=AppointmentOut)
async def update_appointment_status(
    patient_id: str,
    appointment_id: str,
    status_update: AppointmentStatusUpdate,
    current=Depends(get_current_user),
):
    """تحديث حالة موعد."""
    doctor_id = await _get_current_doctor_id(current)
    appointment = await patient_service.update_appointment_status(
        appointment_id=appointment_id,
        patient_id=patient_id,
        doctor_id=doctor_id,
        status=status_update.status,
    )
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found or unauthorized")
    
    return AppointmentOut(
        id=str(appointment.id),
        patient_id=str(appointment.patient_id),
        doctor_id=str(appointment.doctor_id),
        scheduled_at=appointment.scheduled_at.isoformat() if appointment.scheduled_at else datetime.now(timezone.utc).isoformat(),
        note=appointment.note,
        image_path=appointment.image_path,
        image_paths=getattr(appointment, 'image_paths', []) if hasattr(appointment, 'image_paths') else (([appointment.image_path] if appointment.image_path else [])),
        status=appointment.status,
    )
