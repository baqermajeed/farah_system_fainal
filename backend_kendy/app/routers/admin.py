from fastapi import APIRouter, Depends, HTTPException, Body
from typing import List

from app.schemas import UserOut, PatientOut, PatientCreate, PatientUpdate
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services.admin_service import (
    create_staff_user,
    create_patient,
)
from app.services.patient_service import update_patient_by_admin, delete_patient
from app.models import Patient, Doctor, AssignmentLog, User
from app.services import patient_service
from app.schemas import AppointmentOut, NoteOut, GalleryOut
from app.utils.patient_profile import build_doctor_profile_map
from datetime import datetime, timezone
from typing import Optional
from beanie import PydanticObjectId as OID

router = APIRouter(
    prefix="/admin", tags=["admin"], dependencies=[Depends(require_roles([Role.ADMIN]))]
)


@router.post("/staff", response_model=UserOut)
async def create_staff(
    phone: str,
    username: str,
    password: str,
    role: Role,
    name: str | None = None,
    imageUrl: str | None = None,
):
    """المدير ينشئ حساب موظف (طبيب/موظف استقبال/مصور/مركز اتصالات/مدير) باستخدام username/password."""
    user = await create_staff_user(
        phone=phone,
        username=username,
        password=password,
        name=name,
        role=role,
        imageUrl=imageUrl,
    )
    # نحوّل الـ ObjectId إلى str يدويًا ليتوافق مع UserOut
    return UserOut(
        id=str(user.id),
        name=user.name,
        phone=user.phone,
        gender=user.gender,
        age=user.age,
        city=user.city,
        imageUrl=user.imageUrl,
        role=user.role,
        doctor_manager=False if role == Role.DOCTOR else None,
    )


@router.get("/staff", response_model=list[UserOut])
async def list_staff(
    role: Role | None = None,
    skip: int = 0,
    limit: int = 100,
):
    """عرض قائمة الموظفين، ويمكن الفلترة حسب الدور."""
    query = User.find()
    if role is not None:
        query = query.find(User.role == role)

    users = await query.skip(skip).limit(limit).to_list()
    out: list[UserOut] = []
    for user in users:
        out.append(
            UserOut(
                id=str(user.id),
                name=user.name,
                phone=user.phone,
                gender=user.gender,
                age=user.age,
                city=user.city,
                imageUrl=user.imageUrl,
                role=user.role,
                doctor_manager=False if user.role == Role.DOCTOR else None,
            )
        )
    return out


@router.patch("/doctors/{doctor_id}/manager")
async def set_doctor_manager(
    doctor_id: str,
    is_manager: bool = Body(..., embed=True),
):
    """تعيين/إلغاء صلاحية "الطبيب المدير" لطبيب معيّن."""
    try:
        did = OID(doctor_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid doctor_id")

    d = await Doctor.get(did)
    if not d:
        raise HTTPException(status_code=404, detail="Doctor not found")

    d.is_manager = bool(is_manager)
    await d.save()
    return {"ok": True, "doctor_id": str(d.id), "is_manager": d.is_manager}

@router.post("/assign", summary="تعيين مريض لأطباء")
async def admin_assign(patient_id: str, doctor_ids: List[str] = [], current=Depends(get_current_user)):
    """تعيين/تحويل المريض إلى قائمة من الأطباء مع تسجيل الحدث."""
    from app.services.patient_service import assign_patient_doctors
    p = await assign_patient_doctors(patient_id=patient_id, doctor_ids=doctor_ids, assigned_by_user_id=str(current.id))
    return {"ok": True, "patient_id": str(p.id), "doctor_ids": [str(did) for did in p.doctor_ids]}


@router.get("/doctors/{doctor_id}/patients", response_model=list[PatientOut])
async def admin_doctor_patients(
    doctor_id: str,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
):
    """عرض مرضى طبيب محدد للمدير (الأحدث إلى الأقدم).

    ملاحظة: الفلترة `date_from/date_to` تكون حسب **تاريخ التحويل/التعيين للطبيب** (AssignmentLog.assigned_at)
    وليس تاريخ إنشاء حساب المريض.
    """
    from app.models import User
    from app.services.stats_service import parse_dates
    from beanie.operators import In as BeanieIn

    try:
        did = OID(doctor_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid doctor_id")

    # Validate doctor exists
    d = await Doctor.get(did)
    if not d:
        raise HTTPException(status_code=404, detail="Doctor not found")

    df, dt = parse_dates(date_from, date_to)
    # Ensure timezone-aware comparisons (dashboard sends UTC ISO with 'Z')
    if df and df.tzinfo is None:
        df = df.replace(tzinfo=timezone.utc)
    if dt and dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)

    # If a date range is provided, filter by assignment logs (transfer/assign time).
    # Otherwise, return all currently assigned patients.
    assigned_at_by_patient: dict[OID, datetime] = {}

    if df or dt:
        logs_query = AssignmentLog.find(AssignmentLog.doctor_id == did)
        if df:
            logs_query = logs_query.find(AssignmentLog.assigned_at >= df)
        if dt:
            logs_query = logs_query.find(AssignmentLog.assigned_at < dt)
        logs = await logs_query.sort(-AssignmentLog.assigned_at).to_list()
        if not logs:
            return []
        for log in logs:
            # first seen is the latest due to sort desc
            if log.patient_id not in assigned_at_by_patient:
                assigned_at_by_patient[log.patient_id] = log.assigned_at
        patient_ids = list(assigned_at_by_patient.keys())
        patients = await Patient.find(
            BeanieIn(Patient.id, patient_ids),
            BeanieIn(Patient.doctor_ids, [did]),
        ).to_list()
    else:
        patients = await Patient.find(BeanieIn(Patient.doctor_ids, [did])).to_list()

        # sort by latest assignment (if any), fallback to patient id time
        logs = await AssignmentLog.find(AssignmentLog.doctor_id == did).sort(-AssignmentLog.assigned_at).to_list()
        for log in logs:
            if log.patient_id not in assigned_at_by_patient:
                assigned_at_by_patient[log.patient_id] = log.assigned_at

    if not patients:
        return []

    user_ids = list({p.user_id for p in patients if p.user_id})
    users = await User.find(BeanieIn(User.id, user_ids)).to_list()
    user_map = {u.id: u for u in users}

    # Sort newest first (Mongo ObjectId generation time)
    def _oid_time(p: Patient):
        try:
            return p.id.generation_time  # type: ignore[attr-defined]
        except Exception:
            return datetime.min.replace(tzinfo=timezone.utc)

    def _sort_key(p: Patient) -> datetime:
        # assignment time first (if present), fallback to patient creation time
        at = assigned_at_by_patient.get(p.id)
        if at is not None:
            if at.tzinfo is None:
                return at.replace(tzinfo=timezone.utc)
            return at
        return _oid_time(p)

    patients.sort(key=_sort_key, reverse=True)

    filtered = []
    for p in patients:
        u = user_map.get(p.user_id)
        if not u:
            continue
        filtered.append((p, u))

    start = max(0, skip)
    end = start + max(1, min(limit, 100))
    page = filtered[start:end]

    return [
        PatientOut(
            id=str(p.id),
            user_id=str(p.user_id),
            name=u.name,
            phone=u.phone,
            gender=u.gender,
            age=u.age,
            city=u.city,
            treatment_type=p.treatment_type,
            visit_type=getattr(p, "visit_type", None),
            consultation_type=getattr(p, "consultation_type", None),
            payment_methods=getattr(p, "payment_methods", None),
            doctor_ids=[str(did) for did in (p.doctor_ids or [])],
            doctor_profiles=build_doctor_profile_map(p),
            qr_code_data=p.qr_code_data,
            qr_image_path=p.qr_image_path,
            imageUrl=u.imageUrl,
            created_at=p.created_at.isoformat() if getattr(p, "created_at", None) else None,
        )
        for (p, u) in page
    ]

@router.post("/patients", response_model=PatientOut)
async def create_patient_admin(payload: PatientCreate):
    """إنشاء مريض جديد من لوحة المدير مع توليد QR تلقائيًا (MongoDB/Beanie)."""
    # استخدم خدمة create_patient المبنية على Beanie
    p = await create_patient(
        phone=payload.phone,
        name=payload.name,
        gender=payload.gender,
        age=payload.age,
        city=payload.city,
        visit_type=payload.visit_type,
        consultation_type=payload.consultation_type,
    )
    # جلب بيانات المستخدم المرتبط بالمريض
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
        consultation_type=getattr(p, "consultation_type", None),
        payment_methods=getattr(p, "payment_methods", None),
        doctor_ids=[str(did) for did in p.doctor_ids],
        doctor_profiles=build_doctor_profile_map(p),
        qr_code_data=p.qr_code_data,
        qr_image_path=p.qr_image_path,
        imageUrl=u.imageUrl if u else None,
        created_at=p.created_at.isoformat() if getattr(p, "created_at", None) else None,
    )

# تم نقل الإحصائيات إلى /stats router
# هذه endpoints للتوافق مع الإصدارات القديمة
@router.get("/stats")
async def stats():
    """إحصائيات بسيطة: عدد المرضى وإجمالي المرضى لكل طبيب (أساسي فقط).
    ملاحظة: تم نقل الإحصائيات الشاملة إلى /stats/dashboard
    """
    from app.services.stats_service import get_doctors_stats
    stats = await get_doctors_stats()
    return {
        "total_patients": sum(d["total_patients"] for d in stats["doctors"]),
        "per_doctor": [
            {
                "doctor_id": d["doctor_id"],
                "user_id": d["user_id"],
                "patients_primary": d["primary_patients"]
            }
            for d in stats["doctors"]
        ]
    }

@router.patch("/patients/{patient_id}", response_model=PatientOut)
async def update_patient_admin(patient_id: str, payload: PatientUpdate):
    """تعديل بيانات مريض من قبل المدير (يشمل تغيير الهاتف)."""
    p = await update_patient_by_admin(patient_id=patient_id, data=payload)
    from app.models import User
    u = await User.get(p.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
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
        consultation_type=getattr(p, "consultation_type", None),
        payment_methods=getattr(p, "payment_methods", None),
        doctor_ids=[str(did) for did in p.doctor_ids],
        doctor_profiles=build_doctor_profile_map(p),
        qr_code_data=p.qr_code_data,
        qr_image_path=p.qr_image_path,
        imageUrl=u.imageUrl,
        created_at=p.created_at.isoformat() if getattr(p, "created_at", None) else None,
    )

@router.delete("/patients/{patient_id}", status_code=204)
async def delete_patient_admin(patient_id: str):
    """حذف مريض نهائيًا من قبل المدير (يشمل حذف المستخدم وكل متعلقاته)."""
    await delete_patient(actor_role=Role.ADMIN, patient_id=patient_id)
    return None

@router.get("/patients/{patient_id}/appointments", response_model=list[AppointmentOut])
async def admin_patient_appointments(patient_id: str):
    primary, secondary = await patient_service.list_patient_appointments_grouped(patient_id=patient_id)
    all_apps = primary + secondary
    # Need to build AppointmentOut manually with patient_name and doctor_name
    from app.models import User
    import asyncio
    
    async def build_appointment_out(a):
        patient_name = None
        try:
            apt_patient = await Patient.get(a.patient_id)
            if apt_patient:
                user = await User.get(apt_patient.user_id)
                if user:
                    patient_name = user.name
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
        
        return AppointmentOut(
            id=str(a.id),
            patient_id=str(a.patient_id),
            patient_name=patient_name,
            doctor_id=str(a.doctor_id),
            doctor_name=doctor_name,
            scheduled_at=a.scheduled_at.isoformat(),
            note=a.note,
            image_path=a.image_path,
            image_paths=a.image_paths or [],
            status=a.status,
        )
    
    return await asyncio.gather(*[build_appointment_out(a) for a in all_apps])

@router.get("/patients/{patient_id}/notes", response_model=list[NoteOut])
async def admin_patient_notes(patient_id: str):
    notes = await patient_service.list_notes_for_patient(patient_id=patient_id)
    return [NoteOut.model_validate(n) for n in notes]

@router.get("/patients/{patient_id}/gallery", response_model=list[GalleryOut])
async def admin_patient_gallery(patient_id: str):
    gallery = await patient_service.list_gallery_for_patient(patient_id=patient_id)
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
            # Skip this image if there's an error
            continue
    return result
