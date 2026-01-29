from fastapi import APIRouter, Depends, Query, Body, HTTPException, UploadFile, File
from typing import List, Optional
from datetime import datetime, timezone
import re

from beanie.operators import In

from app.schemas import (
    DoctorOut,
    PatientOut,
    PatientCreate,
    AppointmentOut,
    ReceptionAppointmentOut,
    WorkingHoursOut,
    GalleryOut,
)
from app.security import require_roles, get_current_user
from app.constants import Role
from app.models import Patient, User
from app.services import patient_service
from app.services.admin_service import create_patient
from app.services.doctor_working_hours_service import DoctorWorkingHoursService
from app.utils.r2_clinic import upload_clinic_image
from app.utils.patient_profile import build_doctor_profile_map

PHONE_PATTERN = re.compile(r"^07\d{9}$")
IMAGE_TYPES = (
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
)

router = APIRouter(
    prefix="/reception",
    tags=["reception"],
    dependencies=[Depends(require_roles([Role.RECEPTIONIST, Role.ADMIN]))],
)
working_hours_service = DoctorWorkingHoursService()

@router.get("/patients", response_model=List[PatientOut])
async def list_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """يعرض جميع المرضى مع بياناتهم الأساسية."""
    patients = await Patient.find({}).sort(-Patient.id).skip(skip).limit(limit).to_list()
    out: List[PatientOut] = []
    user_ids = list({p.user_id for p in patients if p.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    for p in patients:
        u = user_map.get(p.user_id)
        # محاولة الحصول على treatment_type من doctor_profiles إذا كان p.treatment_type None
        treatment_type = p.treatment_type
        if not treatment_type and p.doctor_profiles:
            # نأخذ treatment_type من أول doctor_profile موجود
            for profile in p.doctor_profiles.values():
                if profile and profile.treatment_type:
                    treatment_type = profile.treatment_type
                    break
        
        out.append(PatientOut(
            id=str(p.id),
            user_id=str(p.user_id),
            name=u.name if u else None,
            phone=u.phone if u else "",
            gender=u.gender if u else None,
            age=u.age if u else None,
            city=u.city if u else None,
            treatment_type=treatment_type,
            visit_type=getattr(p, "visit_type", None),
            doctor_ids=[str(did) for did in p.doctor_ids],
            doctor_profiles=build_doctor_profile_map(p),
            qr_code_data=p.qr_code_data,
            qr_image_path=p.qr_image_path,
            imageUrl=u.imageUrl if u else None,
        ))
    return out


@router.get("/doctors/{doctor_id}/working-hours", response_model=List[WorkingHoursOut])
async def get_doctor_working_hours_for_reception(doctor_id: str):
    """جلب أوقات عمل طبيب محدد (للاستقبال/الادمن)."""
    result = await working_hours_service.get_doctor_working_hours(doctor_id)
    return [
        WorkingHoursOut(
            id=str(wh.id),
            doctor_id=str(wh.doctor_id),
            day_of_week=wh.day_of_week,
            start_time=wh.start_time,
            end_time=wh.end_time,
            is_working=wh.is_working,
            slot_duration=wh.slot_duration,
            created_at=wh.created_at.isoformat()
            if wh.created_at
            else datetime.now(timezone.utc).isoformat(),
            updated_at=wh.updated_at.isoformat()
            if wh.updated_at
            else datetime.now(timezone.utc).isoformat(),
        )
        for wh in result
    ]


@router.get("/doctors/{doctor_id}/available-slots/{date}", response_model=List[str])
async def get_doctor_available_slots_for_reception(doctor_id: str, date: str):
    """جلب الأوقات المتاحة لطبيب محدد في يوم معين (للاستقبال/الادمن)."""
    return await working_hours_service.get_available_slots(doctor_id=doctor_id, date=date)

@router.get("/doctors", response_model=List[DoctorOut])
async def list_doctors():
    """جلب قائمة جميع الأطباء المتاحين."""
    from app.models import Doctor
    doctors = await Doctor.find({}).to_list()
    out: List[DoctorOut] = []
    user_ids = list({d.user_id for d in doctors if d.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}
    
    for d in doctors:
        u = user_map.get(d.user_id)
        # Get imageUrl from user if available (assuming it might be added later)
        image_url = getattr(u, 'imageUrl', None) if u else None
        out.append(DoctorOut(
            id=str(d.id),
            user_id=str(d.user_id),
            name=u.name if u else None,
            phone=u.phone if u else "",
            imageUrl=image_url,
        ))
    return out

@router.get("/patients/{patient_id}/doctors", response_model=List[DoctorOut])
async def get_patient_doctors(patient_id: str):
    """جلب قائمة الأطباء المرتبطين بمريض."""
    from app.models import Doctor
    patient = await Patient.get(patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    if not patient.doctor_ids:
        return []
    
    doctors = await Doctor.find(In(Doctor.id, patient.doctor_ids)).to_list()
    user_ids = list({d.user_id for d in doctors if d.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}
    
    out: List[DoctorOut] = []
    for d in doctors:
        u = user_map.get(d.user_id)
        # Get imageUrl from user if available (assuming it might be added later)
        image_url = getattr(u, 'imageUrl', None) if u else None
        out.append(DoctorOut(
            id=str(d.id),
            user_id=str(d.user_id),
            name=u.name if u else None,
            phone=u.phone if u else "",
            imageUrl=image_url,
        ))
    return out

@router.post("/assign")
async def assign_patient(patient_id: str = Query(...), doctor_ids: List[str] = Body(default=[]), current=Depends(require_roles([Role.RECEPTIONIST, Role.ADMIN]))):
    """تحويل/تعيين مريض إلى قائمة من الأطباء."""
    from app.services.patient_service import assign_patient_doctors
    p = await assign_patient_doctors(patient_id=patient_id, doctor_ids=doctor_ids, assigned_by_user_id=str(current.id))
    return {"ok": True, "patient_id": str(p.id), "doctor_ids": [str(did) for did in p.doctor_ids]}

@router.post("/patients", response_model=PatientOut)
async def create_patient_reception(payload: PatientCreate):
    """إضافة مريض جديد من قبل موظف الاستقبال."""
    if not PHONE_PATTERN.match(payload.phone.strip()):
        raise HTTPException(
            status_code=400,
            detail="رقم الهاتف يجب أن يكون 11 رقم ويبدأ بـ 07",
        )
    p = await create_patient(
        phone=payload.phone.strip(),
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        city=payload.city,
        visit_type=payload.visit_type,
    )
    from app.models import User
    u = await User.get(p.user_id)
    return PatientOut(
        id=str(p.id),
        user_id=str(p.user_id),
        name=u.name if u else None,
        phone=u.phone if u else "",
        gender=u.gender if u else None,
        age=u.age if u else None,
        city=u.city if u else None,
        treatment_type=p.treatment_type,
        visit_type=getattr(p, "visit_type", None),
        doctor_ids=[str(did) for did in p.doctor_ids],
        doctor_profiles=build_doctor_profile_map(p),
        qr_code_data=p.qr_code_data,
        qr_image_path=p.qr_image_path,
        imageUrl=u.imageUrl if u else None,
    )


@router.post("/patients/{patient_id}/upload-image", response_model=PatientOut)
async def upload_patient_profile_image(
    patient_id: str,
    image: UploadFile = File(...),
    current=Depends(get_current_user),
):
    """رفع صورة بروفايل للمريض (للاستقبال/الادمن)."""
    if image.content_type not in IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed types: {', '.join(IMAGE_TYPES)}",
        )

    p = await Patient.get(patient_id)
    if not p:
        raise HTTPException(status_code=404, detail="Patient not found")

    u = await User.get(p.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    file_bytes = await image.read()
    image_path = await upload_clinic_image(
        patient_id=str(u.id),
        folder="profile",
        file_bytes=file_bytes,
        content_type=image.content_type,
        name_hint=u.name,
    )
    # upload_clinic_image now returns a direct /media/... URL

    u.imageUrl = image_path
    u.updated_at = datetime.now(timezone.utc)
    await u.save()

    return PatientOut(
        id=str(p.id),
        user_id=str(p.user_id),
        name=u.name,
        phone=u.phone,
        gender=u.gender,
        age=u.age,
        city=u.city,
        treatment_type=p.treatment_type,
        visit_type=getattr(p, "visit_type", None),
        doctor_ids=[str(did) for did in p.doctor_ids],
        doctor_profiles=build_doctor_profile_map(p),
        qr_code_data=p.qr_code_data,
        qr_image_path=p.qr_image_path,
        imageUrl=u.imageUrl,
    )


@router.post("/patients/{patient_id}/gallery", response_model=GalleryOut)
async def upload_patient_gallery_image(
    patient_id: str,
    image: UploadFile = File(...),
    note: str | None = None,
    current=Depends(get_current_user),
):
    """
    رفع صورة إلى معرض المريض من قبل موظف الاستقبال/الادمن.

    - تظهر هذه الصورة في معرض المريض (للمريض والطبيب).
    - عند استعلام موظف الاستقبال عن المعرض من واجهته، نعرض له فقط
      الصور التي قام برفعها بنفسه (باستخدام endpoint منفصل).
    """
    if IMAGE_TYPES and image.content_type not in IMAGE_TYPES:
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
    )
    gi = await patient_service.create_gallery_image(
        patient_id=patient_id,
        uploaded_by_user_id=str(current.id),
        image_path=image_path,
        note=note,
        doctor_id=None,
    )
    return GalleryOut(
        id=str(gi.id),
        patient_id=str(gi.patient_id),
        image_path=gi.image_path,
        note=gi.note,
        created_at=gi.created_at.isoformat()
        if gi.created_at
        else datetime.now(timezone.utc).isoformat(),
    )


@router.get("/patients/{patient_id}/gallery", response_model=List[GalleryOut])
async def list_my_uploaded_gallery_images(
    patient_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
    current=Depends(get_current_user),
):
    """
    إرجاع صور المعرض التي قام موظف الاستقبال الحالي برفعها لهذا المريض فقط.

    - لا يرى موظف الاستقبال باقي صور المريض (المرفوعة من الأطباء أو المصور).
    """
    gallery = await patient_service.list_gallery_for_patient_by_uploader(
        patient_id=patient_id,
        uploaded_by_user_id=str(current.id),
        skip=skip,
        limit=limit,
    )
    result: List[GalleryOut] = []
    for g in gallery:
        try:
            result.append(
                GalleryOut(
                    id=str(g.id),
                    patient_id=str(g.patient_id),
                    image_path=g.image_path,
                    note=g.note,
                    created_at=g.created_at.isoformat()
                    if g.created_at
                    else datetime.now(timezone.utc).isoformat(),
                )
            )
        except Exception:
            # في حال وجود خطأ في سجل معيّن، نتجاوزه ولا نوقف الاستعلام بالكامل
            continue
    return result


@router.get("/appointments", response_model=List[ReceptionAppointmentOut])
async def list_appointments(
    day: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    status: str | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
):
    """جداول مواعيد جميع المرضى (اليوم/غدًا/نطاق تاريخ)، مع خيار المتأخرون."""
    df = datetime.fromisoformat(date_from) if date_from else None
    dt = datetime.fromisoformat(date_to) if date_to else None
    # ✅ احترام skip/limit القادمة من العميل لتحسين الأداء ومنع تجمّد الواجهة
    apps = await patient_service.list_appointments_for_all(
        day=day,
        date_from=df,
        date_to=dt,
        status=status,
        skip=skip,
        limit=limit,
    )
    # نحضر معلومات المرضى والأطباء المرتبطة بهذه المواعيد
    from app.models import Patient, User, Doctor
    from beanie.operators import In as BeanieIn

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

        out.append(
            ReceptionAppointmentOut(
                id=str(a.id),
                patient_id=str(a.patient_id),
                patient_name=pu.name if pu else None,
                patient_phone=pu.phone if pu else None,
                doctor_id=str(a.doctor_id),
                doctor_name=du.name if du else None,
                scheduled_at=a.scheduled_at.isoformat()
                if isinstance(a.scheduled_at, datetime)
                else str(a.scheduled_at),
                note=a.note,
                image_path=a.image_path,
                status=a.status,
            )
        )
    return out
