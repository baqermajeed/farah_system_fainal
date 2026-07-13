from fastapi import APIRouter, Depends, Query, Body, HTTPException, UploadFile, File
from typing import List, Optional
from datetime import datetime, timezone
import re

from beanie import PydanticObjectId as OID
from beanie.operators import In

from app.schemas import (
    DoctorOut,
    PatientOut,
    PatientCreate,
    PatientUpdate,
    AppointmentOut,
    ReceptionAppointmentOut,
    WorkingHoursOut,
    GalleryOut,
    CallCenterAppointmentOut,
    ReceptionQueueSyncIn,
    ReceptionQueueDayOut,
    ReceptionQueueEntryOut,
)
from app.security import require_roles, get_current_user
from app.constants import Role
from app.models import Patient, User, CallCenterAppointment
from app.models.reception_queue import ReceptionQueueDay, ReceptionQueueEntry
from app.services.staff_appointment_service import list_staff_appointments
from app.services.stats_service import parse_dates
from app.services import patient_service
from app.services.admin_service import create_patient
from app.services.doctor_working_hours_service import DoctorWorkingHoursService
from app.utils.r2_clinic import upload_clinic_image
from app.utils.patient_profile import build_doctor_profile_map
from app.utils.patient_out import build_patient_out, patient_name_hint_for_id, build_patient_out_from_agg

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
    search: Optional[str] = Query(None, description="بحث في اسم المريض أو رقم الهاتف"),
):
    """يعرض جميع المرضى مع بياناتهم الأساسية مرتبة حسب الأحدث أولاً."""
    # ترتيب حسب تاريخ إنشاء ملف المريض (فرد العائلة)، وليس تاريخ حساب الهاتف
    
    pipeline = [
        {
            "$lookup": {
                "from": "users",
                "localField": "user_id",
                "foreignField": "_id",
                "as": "user_data"
            }
        },
        {
            "$unwind": {
                "path": "$user_data",
                "preserveNullAndEmptyArrays": False  # نتجاهل المرضى بدون users
            }
        }
    ]
    
    # ⭐ إضافة البحث إذا كان موجوداً
    if search and search.strip():
        search_lower = search.strip().lower()
        pipeline.insert(-1, {
            "$match": {
                "$or": [
                    {"name": {"$regex": search_lower, "$options": "i"}},
                    {"user_data.name": {"$regex": search_lower, "$options": "i"}},
                    {"user_data.phone": {"$regex": search_lower, "$options": "i"}},
                ]
            }
        })
    
    # إضافة الترتيب والـ pagination
    pipeline.extend([
        {
            "$addFields": {
                "sort_date": {"$ifNull": ["$created_at", "$_id"]}
            }
        },
        {
            "$sort": {"sort_date": -1, "_id": -1}
        },
        {
            "$skip": skip
        },
        {
            "$limit": limit
        }
    ])
    
    patients_with_users = await Patient.aggregate(pipeline).to_list()
    
    out: List[PatientOut] = []
    for item in patients_with_users:
        user_data = item.get("user_data", {})
        if not user_data:
            continue
        out.append(build_patient_out_from_agg(item, user_data))
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
    from app.services.socket_service import is_user_online

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
            is_online=is_user_online(str(d.user_id)),
        ))
    return out

@router.get("/patients/{patient_id}/doctors", response_model=List[DoctorOut])
async def get_patient_doctors(patient_id: str):
    """جلب قائمة الأطباء المرتبطين بمريض."""
    from app.models import Doctor
    from app.services.socket_service import is_user_online
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
            is_online=is_user_online(str(d.user_id)),
        ))
    return out

@router.post("/assign")
async def assign_patient(patient_id: str = Query(...), doctor_ids: List[str] = Body(default=[]), current=Depends(require_roles([Role.RECEPTIONIST, Role.ADMIN]))):
    """تحويل/تعيين مريض إلى قائمة من الأطباء."""
    from app.services.patient_service import assign_patient_doctors
    p = await assign_patient_doctors(patient_id=patient_id, doctor_ids=doctor_ids, assigned_by_user_id=str(current.id))
    return {"ok": True, "patient_id": str(p.id), "doctor_ids": [str(did) for did in p.doctor_ids]}

@router.get("/family-by-phone")
async def lookup_family_by_phone(
    phone: str = Query(..., description="رقم هاتف العائلة"),
):
    """التحقق إن كان رقم الهاتف حساب عائلة موجوداً مع أسماء الأفراد."""
    phone = phone.strip()
    if not PHONE_PATTERN.match(phone):
        raise HTTPException(
            status_code=400,
            detail="رقم الهاتف يجب أن يكون 11 رقم ويبدأ بـ 07",
        )

    existing_user = await User.find_one(User.phone == phone)
    if not existing_user or existing_user.role != Role.PATIENT:
        return {
            "exists": False,
            "family_member_count": 0,
            "members": [],
        }

    patients = await Patient.find(Patient.user_id == existing_user.id).to_list()
    members = []
    for p in patients:
        identity = build_patient_out(p, existing_user)
        members.append(
            {
                "id": identity.id,
                "name": identity.name,
                "is_primary": identity.is_primary,
                "relationship": identity.relationship,
            }
        )

    return {
        "exists": True,
        "family_member_count": len(members),
        "members": members,
    }


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
        consultation_type=payload.consultation_type,
    )
    u = await User.get(p.user_id)
    return build_patient_out(p, u)


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
        patient_id=str(p.id),
        folder="profile",
        file_bytes=file_bytes,
        content_type=image.content_type,
        name_hint=p.name or u.name,
    )

    p.imageUrl = image_path
    await p.save()

    return build_patient_out(p, u)


@router.post("/patients/{patient_id}/activate", response_model=PatientOut)
async def activate_patient(patient_id: str):
    """تنشيط مريض (pending -> active) من قبل موظف الاستقبال/المدير."""
    p = await patient_service.activate_patient_by_reception(patient_id=patient_id)
    u = await User.get(p.user_id)
    return build_patient_out(p, u)


@router.patch("/patients/{patient_id}/activity-status", response_model=PatientOut)
async def update_patient_activity_status(
    patient_id: str,
    status: str = Body(..., embed=True),
):
    """تحديث حالة المريض من الاستقبال (pending | active | inactive)."""
    p = await patient_service.update_patient_activity_status_by_reception(
        patient_id=patient_id,
        status=status,
    )
    u = await User.get(p.user_id)
    return build_patient_out(p, u)


@router.patch("/patients/{patient_id}", response_model=PatientOut)
async def update_patient_profile_by_reception(
    patient_id: str,
    payload: PatientUpdate,
):
    """تعديل بيانات مريض من قبل موظف الاستقبال/المدير."""
    if payload.phone is not None and not PHONE_PATTERN.match(payload.phone.strip()):
        raise HTTPException(
            status_code=400,
            detail="رقم الهاتف يجب أن يكون 11 رقم ويبدأ بـ 07",
        )

    p = await patient_service.update_patient_by_admin(
        patient_id=patient_id,
        data=payload,
    )
    u = await User.get(p.user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    return build_patient_out(p, u)


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
    patient_name_hint = await patient_name_hint_for_id(patient_id)
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
    day: str | None = Query(None, description="today (اليوم) | month (هذا الشهر)"),
    date_from: str | None = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: str | None = Query(None, description="تاريخ النهاية (ISO format)"),
    status: str | None = Query(None, description="late (المتأخرون) | pending | completed | cancelled"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
):
    """
    جداول مواعيد جميع المرضى لموظف الاستقبال.

    التبويبات:
    - day=today: مواعيد اليوم
    - day=month: مواعيد هذا الشهر
    - status=late: المواعيد المتأخرة
    - date_from & date_to: تصفية حسب التاريخ (من - إلى)

    يعرض: صورة المريض، اسم المريض، اسم الطبيب، يوم الموعد، تاريخ الموعد، الساعة، رقم هاتف المريض.
    المواعيد المكتملة والملغية لا تظهر في الجداول.
    """
    try:
        return await list_staff_appointments(
            day=day,
            date_from=date_from,
            date_to=date_to,
            status=status,
            skip=skip,
            limit=limit,
        )
    except HTTPException:
        raise
    except Exception as e:
        from app.utils.logger import get_logger
        logger = get_logger("reception_router")
        logger.error(f"Error in list_appointments: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@router.get("/call-center-appointments", response_model=List[CallCenterAppointmentOut])
async def list_call_center_appointments_for_reception(
    date_from: Optional[str] = Query(None, description="فلترة حسب تاريخ الموعد من (ISO)"),
    date_to: Optional[str] = Query(None, description="فلترة حسب تاريخ الموعد إلى (ISO)"),
    search: Optional[str] = Query(None, description="بحث بالاسم أو الهاتف أو يوزر الموظف"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
):
    """عرض مواعيد مركز الاتصالات غير المقبولة فقط (المقبولة تُخفى من قائمة الاستقبال)."""
    df, dt = parse_dates(date_from, date_to)
    query = CallCenterAppointment.find(CallCenterAppointment.status == "pending")

    if df:
        query = query.find(CallCenterAppointment.scheduled_at >= df)
    if dt:
        query = query.find(CallCenterAppointment.scheduled_at < dt)

    if search and search.strip():
        s = search.strip()
        query = query.find(
            {
                "$or": [
                    {"patient_name": {"$regex": s, "$options": "i"}},
                    {"patient_phone": {"$regex": s, "$options": "i"}},
                    {"created_by_username": {"$regex": s, "$options": "i"}},
                ]
            }
        )

    items = await query.sort("-created_at").skip(skip).limit(limit).to_list()

    return [
        CallCenterAppointmentOut(
            id=str(i.id),
            patient_name=i.patient_name,
            patient_phone=i.patient_phone,
            scheduled_at=i.scheduled_at.isoformat(),
            governorate=getattr(i, "governorate", "") or "",
            platform=getattr(i, "platform", "") or "",
            note=getattr(i, "note", "") or "",
            created_by_user_id=str(i.created_by_user_id),
            created_by_username=i.created_by_username,
            created_at=i.created_at.isoformat(),
            status=getattr(i, "status", "pending") or "pending",
            accepted_at=i.accepted_at.isoformat() if getattr(i, "accepted_at", None) else None,
        )
        for i in items
    ]


@router.post("/call-center-appointments/{appointment_id}/accept")
async def accept_call_center_appointment_for_reception(
    appointment_id: str,
):
    """موظف الاستقبال يقبل الموعد: يُخفى من قائمة الاستقبال (يُعلّم مقبولاً) ويزيد عداد المواعيد المقبولة في حساب موظف الـ call center. في حساب الـ call center يبقى الموعد ويظهر الصف بلون أخضر."""
    try:
        oid = OID(appointment_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid appointment id")

    doc = await CallCenterAppointment.get(oid)
    if not doc:
        raise HTTPException(status_code=404, detail="الموعد غير موجود")

    creator_id = doc.created_by_user_id
    creator = await User.get(creator_id)
    if creator:
        creator.call_center_accepted_count = getattr(
            creator, "call_center_accepted_count", 0
        ) + 1
        await creator.save()

    doc.status = "accepted"
    doc.accepted_at = datetime.now(timezone.utc)
    await doc.save()
    return {"ok": True, "accepted": True}


_DATE_KEY_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _queue_day_out(doc: ReceptionQueueDay) -> ReceptionQueueDayOut:
    return ReceptionQueueDayOut(
        date=doc.date,
        total_count=doc.total_count,
        entries=[
            ReceptionQueueEntryOut(number=e.number, name=e.name) for e in doc.entries
        ],
        updated_at=doc.updated_at.isoformat(),
    )


@router.put("/queue", response_model=ReceptionQueueDayOut)
async def sync_reception_queue(payload: ReceptionQueueSyncIn):
    """
    أرشفة طابور الاستقبال ليوم محدد في قاعدة البيانات.
    العرض والنداء يبقيان محليين على جهاز الاستقبال؛ هنا يُحفظ فقط:
    عدد المضافين، الأسماء، وأرقامهم في الطابور.
    """
    date_key = (payload.date or "").strip()
    if not _DATE_KEY_RE.match(date_key):
        raise HTTPException(status_code=400, detail="صيغة التاريخ يجب أن تكون YYYY-MM-DD")

    # ترتيب حسب الرقم وإزالة التكرار على نفس الرقم (آخر اسم يفوز)
    by_number: dict[int, str] = {}
    for item in payload.entries:
        name = (item.name or "").strip()
        if not name:
            continue
        by_number[item.number] = name

    entries = [
        ReceptionQueueEntry(number=num, name=by_number[num])
        for num in sorted(by_number.keys())
    ]
    now = datetime.now(timezone.utc)

    doc = await ReceptionQueueDay.find_one(ReceptionQueueDay.date == date_key)
    if doc:
        doc.entries = entries
        doc.total_count = len(entries)
        doc.updated_at = now
        await doc.save()
    else:
        doc = ReceptionQueueDay(
            date=date_key,
            entries=entries,
            total_count=len(entries),
            updated_at=now,
        )
        await doc.insert()

    return _queue_day_out(doc)


@router.get("/queue", response_model=ReceptionQueueDayOut)
async def get_reception_queue(
    date: str | None = Query(None, description="YYYY-MM-DD — افتراضي: اليوم (UTC)"),
):
    """جلب أرشيف طابور يوم محدد (للتقارير؛ لا يُستخدم لعرض شاشة الطابور)."""
    if date:
        date_key = date.strip()
        if not _DATE_KEY_RE.match(date_key):
            raise HTTPException(status_code=400, detail="صيغة التاريخ يجب أن تكون YYYY-MM-DD")
    else:
        now = datetime.now(timezone.utc)
        date_key = f"{now.year:04d}-{now.month:02d}-{now.day:02d}"

    doc = await ReceptionQueueDay.find_one(ReceptionQueueDay.date == date_key)
    if not doc:
        return ReceptionQueueDayOut(
            date=date_key,
            total_count=0,
            entries=[],
            updated_at=datetime.now(timezone.utc).isoformat(),
        )
    return _queue_day_out(doc)
