from fastapi import APIRouter, Depends, UploadFile, File, Query, Form, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional, Dict
from datetime import datetime, timezone
from pydantic import BaseModel
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
    AppointmentDateTimeUpdate,
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

from app.models import InactivePatientLog  # لاسترجاع المرضى غير النشطين

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
    payment_methods = doctor_profile.payment_methods if doctor_profile else None
    
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
        consultation_type=getattr(patient, "consultation_type", None),
        payment_methods=payment_methods,
        doctor_ids=[str(did) for did in patient.doctor_ids],
        doctor_profiles=doctor_profiles,
        qr_code_data=patient.qr_code_data,
        qr_image_path=patient.qr_image_path,
        imageUrl=user.imageUrl,
        created_at=patient.created_at.isoformat() if getattr(patient, "created_at", None) else None,
    )


def _build_doctor_patient_out_from_agg(patient_doc: dict, user_doc: dict, doctor_id: str) -> PatientOut:
    """Build PatientOut directly from aggregation result (no Beanie re-fetch)."""

    from app.schemas import DoctorPatientProfileOut

    doctor_key = str(doctor_id)
    doctor_profiles_raw = patient_doc.get("doctor_profiles", {}) or {}

    doctor_profiles_out: Dict[str, DoctorPatientProfileOut] = {}

    profile = doctor_profiles_raw.get(doctor_key)
    if profile:
        def parse_dt(v):
            if isinstance(v, str):
                try:
                    return datetime.fromisoformat(v.replace("Z", "+00:00"))
                except Exception:
                    return None
            return v

        doctor_profiles_out[doctor_key] = DoctorPatientProfileOut(
            treatment_type=profile.get("treatment_type"),
            assigned_at=parse_dt(profile.get("assigned_at")),
            last_action_at=parse_dt(profile.get("last_action_at")),
            payment_methods=profile.get("payment_methods"),
        )

    treatment_type = None
    payment_methods = None
    if profile:
        treatment_type = profile.get("treatment_type")
        payment_methods = profile.get("payment_methods")

    return PatientOut(
        id=str(patient_doc["_id"]),
        user_id=str(patient_doc.get("user_id")),
        name=user_doc.get("name"),
        phone=user_doc.get("phone", ""),
        gender=user_doc.get("gender"),
        age=user_doc.get("age"),
        city=user_doc.get("city"),
        treatment_type=treatment_type,
        visit_type=patient_doc.get("visit_type"),
        consultation_type=patient_doc.get("consultation_type"),
        payment_methods=payment_methods,
        doctor_ids=[str(d) for d in patient_doc.get("doctor_ids", [])],
        doctor_profiles=doctor_profiles_out,
        qr_code_data=patient_doc.get("qr_code_data", ""),
        qr_image_path=patient_doc.get("qr_image_path"),
        imageUrl=user_doc.get("imageUrl"),
        created_at=(
            patient_doc.get("created_at").isoformat()
            if isinstance(patient_doc.get("created_at"), datetime)
            else str(patient_doc.get("created_at")) if patient_doc.get("created_at") else None
        ),
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
        consultation_type=payload.consultation_type,
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


@router.get("/doctors/transfer-stats")
async def get_all_doctors_transfer_stats(
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(get_current_user),
):
    """
    إحصائيات التحويلات لجميع الأطباء (للطبيب المدير فقط).
    
    يعرض لكل طبيب:
    - عدد المرضى المحولين يومياً وشهرياً
    - عدد المرضى النشطين يومياً وشهرياً
    - عدد المرضى غير النشطين يومياً وشهرياً
    
    يمكن تصفية النتائج حسب فترة محددة باستخدام date_from و date_to.
    """
    _ = await _require_doctor_manager(current)
    
    from app.services.stats_service import get_all_doctors_patient_transfer_stats
    
    return await get_all_doctors_patient_transfer_stats(
        date_from=date_from,
        date_to=date_to,
    )


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
    search: Optional[str] = Query(None, description="بحث في اسم المريض أو رقم الهاتف"),
    current=Depends(get_current_user),
):
    doctor_id = await _get_current_doctor_id(current)

    # قبل إرجاع المرضى، ننظّف المرضى الجدد غير النشطين من حساب هذا الطبيب
    try:
        from app.services import patient_service
        await patient_service.cleanup_inactive_new_patients_for_doctor(doctor_id=doctor_id)
    except Exception as e:
        logger.error(f"Error during cleanup_inactive_new_patients_for_doctor for doctor {doctor_id}: {e}")

    try:
        did = OID(doctor_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid doctor_id format: {doctor_id}")

    pipeline = [
        {
            "$match": {
                "doctor_ids": {"$in": [did]},
            }
        },
        {
            "$lookup": {
                "from": "users",
                "localField": "user_id",
                "foreignField": "_id",
                "as": "user_data",
            }
        },
        {
            "$unwind": {
                "path": "$user_data",
                "preserveNullAndEmptyArrays": True,
            }
        },
    ]

    if search and search.strip():
        search_lower = search.strip()
        pipeline.append(
            {
                "$match": {
                    "$or": [
                        {"user_data.name": {"$regex": search_lower, "$options": "i"}},
                        {"user_data.phone": {"$regex": search_lower, "$options": "i"}},
                    ]
                }
            }
        )

    pipeline.append(
        {
            "$addFields": {
                "sort_date": {"$ifNull": ["$user_data.created_at", "$_id"]}
            }
        }
    )

    pipeline.extend(
        [
            {"$sort": {"sort_date": -1}},
            {"$skip": skip},
            {"$limit": limit},
        ]
    )

    patients_with_users = await Patient.aggregate(pipeline).to_list()

    logger.info(
        f"📊 [my_patients] Doctor ID: {doctor_id}, Found {len(patients_with_users)} patients from aggregation"
    )

    out: List[PatientOut] = []
    skipped_no_user_data = 0

    for item in patients_with_users:
        user_data = item.get("user_data")

        if not user_data or not user_data.get("_id"):
            skipped_no_user_data += 1
            logger.warning(
                f"⚠️ [my_patients] Skipping patient {item.get('_id')}: no user_data"
            )
            continue

        try:
            out.append(
                _build_doctor_patient_out_from_agg(
                    patient_doc=item,
                    user_doc=user_data,
                    doctor_id=doctor_id,
                )
            )
        except Exception as e:
            logger.error(
                f"❌ [my_patients] Error building PatientOut for {item.get('_id')}: {e}"
            )

    logger.info(
        f"✅ [my_patients] Returning {len(out)} patients (skipped: {skipped_no_user_data} no user_data)"
    )

    return out


@router.get("/patients/inactive", response_model=List[PatientOut])
async def my_inactive_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
    current=Depends(get_current_user),
):
    """
    قائمة المرضى غير النشطين لهذا الطبيب.

    التعريف الحالي لغير النشطين:
    - مرضى جدد (visit_type == "مريض جديد") تم تحويلهم للطبيب لكن لم يقم
      الطبيب بأي إجراء عليهم في يوم التحويل الأول، وتمت إزالتهم تلقائياً
      من قائمته بواسطة منطق `cleanup_inactive_new_patients_for_doctor`.
    - يتم الاعتماد على سجلات `InactivePatientLog` لحساب هؤلاء المرضى.
    """
    doctor_id = await _get_current_doctor_id(current)

    try:
        did = OID(doctor_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid doctor_id format: {doctor_id}") from e

    # نجلب سجلات المرضى غير النشطين لهذا الطبيب مرتبة من الأحدث إلى الأقدم
    logs_query = (
        InactivePatientLog.find(InactivePatientLog.doctor_id == did)
        .sort("-removed_at")
        .skip(skip)
    )
    if limit is not None:
        logs_query = logs_query.limit(limit)

    logs: List[InactivePatientLog] = await logs_query.to_list()

    if not logs:
        return []

    # جمع معرّفات المرضى
    patient_ids = [log.patient_id for log in logs]
    patients = await Patient.find(In(Patient.id, patient_ids)).to_list()
    patient_map = {p.id: p for p in patients}

    # جلب المستخدمين المرتبطين بالمرضى
    user_ids = [p.user_id for p in patients if p.user_id]
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    out: List[PatientOut] = []
    for log in logs:
        patient = patient_map.get(log.patient_id)
        if not patient:
            continue
        user = user_map.get(patient.user_id)
        if not user:
            continue
        try:
            out.append(
                _build_doctor_patient_out(
                    patient=patient,
                    user=user,
                    doctor_id=doctor_id,
                )
            )
        except Exception as e:
            logger.error(
                f"❌ [my_inactive_patients] Error building PatientOut for patient {patient.id}: {e}"
            )
            continue

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


class PaymentMethodsIn(BaseModel):
    methods: List[str]


@router.post("/patients/{patient_id}/payment-methods", response_model=PatientOut)
async def set_payment_methods_for_patient(
    patient_id: str,
    payload: PaymentMethodsIn,
    current=Depends(get_current_user),
):
    """
    تحديد طرق الدفع المستخدمة لهذا المريض (من حساب الطبيب).

    - أمثلة الطرق: \"نقد\", \"ماستر كارد\", \"كمبيالة\", \"تعهد\".
    - يمكن اختيار طريقة أو طريقتين (أو أكثر عند الحاجة).
    """
    from pydantic import ValidationError

    ALLOWED_METHODS = {"نقد", "ماستر كارد", "كمبيالة", "تعهد"}

    methods = payload.methods or []

    if not methods:
        raise HTTPException(status_code=400, detail="يجب اختيار طريقة دفع واحدة على الأقل")

    # يمكن توسيع الحد لاحقاً، حالياً نسمح حتى طريقتين كما طلبت
    if len(methods) > 2:
        raise HTTPException(status_code=400, detail="يمكن اختيار طريقتين كحد أقصى لطرق الدفع")

    invalid = [m for m in methods if m not in ALLOWED_METHODS]
    if invalid:
        raise HTTPException(
            status_code=400,
            detail=f"طرق الدفع غير مدعومة: {', '.join(invalid)}",
        )

    doctor_id = await _get_current_doctor_id(current)

    from app.services import patient_service

    p = await patient_service.set_payment_methods(
        patient_id=patient_id,
        doctor_id=doctor_id,
        methods=methods,
    )
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
    day: str | None = Query(None, description="today (مواعيد اليوم) | month (مواعيد هذا الشهر)"),
    date_from: str | None = Query(None, description="تاريخ البداية (ISO format) - للتصفية من"),
    date_to: str | None = Query(None, description="تاريخ النهاية (ISO format) - للتصفية إلى"),
    status: str | None = Query(None, description="late (المواعيد المتأخرة) | pending | completed | cancelled"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1),
    current=Depends(get_current_user),
):
    """
    مواعيد الطبيب مع التبويبات:
    1. day=today: مواعيد اليوم
    2. day=month: مواعيد هذا الشهر
    3. status=late: المواعيد المتأخرة
    4. date_from & date_to: تصفية حسب التاريخ (من - إلى)
    
    المواعيد المكتملة والملغية لا تظهر في الجداول، فقط في ملف المريض.
    """
    try:
        df = None
        dt = None
        if date_from:
            try:
                # دعم تنسيق yyyy-MM-dd و yyyy-MM-ddTHH:mm:ss
                if 'T' in date_from:
                    df = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                else:
                    # إذا كان التاريخ فقط بدون وقت، نضيف وقت 00:00:00
                    df = datetime.fromisoformat(f"{date_from}T00:00:00+00:00")
                if df.tzinfo is None:
                    df = df.replace(tzinfo=timezone.utc)
            except (ValueError, AttributeError) as e:
                logger.error(f"Invalid date_from format: {date_from}, error: {e}")
                raise HTTPException(status_code=400, detail=f"Invalid date_from format: {date_from}")
        
        if date_to:
            try:
                # دعم تنسيق yyyy-MM-dd و yyyy-MM-ddTHH:mm:ss
                if 'T' in date_to:
                    dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
                else:
                    # إذا كان التاريخ فقط بدون وقت، نضيف وقت 23:59:59
                    dt = datetime.fromisoformat(f"{date_to}T23:59:59+00:00")
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
            except (ValueError, AttributeError) as e:
                logger.error(f"Invalid date_to format: {date_to}, error: {e}")
                raise HTTPException(status_code=400, detail=f"Invalid date_to format: {date_to}")
        
        doctor_id = await _get_current_doctor_id(current)
        # ✅ احترام skip/limit القادمة من العميل بدلاً من جلب جميع المواعيد دفعة واحدة
        # هذا يحسن الأداء بشكل كبير ويمنع تجمّد الواجهة الأمامية (frontend)
        apps = await patient_service.list_appointments_for_doctor(
            doctor_id=doctor_id,
            day=day,
            date_from=df,
            date_to=dt,
            status=status,
            skip=skip,
            limit=limit,
        )
        result = []
        for a in apps:
            try:
                # جلب بيانات المريض
                patient_name = None
                patient_phone = None
                try:
                    patient = await Patient.get(a.patient_id)
                    if patient:
                        user = await User.get(patient.user_id)
                        if user:
                            patient_name = user.name
                            patient_phone = user.phone  # ⭐ إضافة رقم الهاتف
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
                        patient_phone=patient_phone,  # ⭐ إضافة رقم الهاتف
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
    except Exception as e:
        logger.error(f"Error in list_my_appointments: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

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
    """
    قائمة مواعيد المريض في ملف المريض في حساب الطبيب.
    يعرض جميع المواعيد بما فيها المكتملة والملغية.
    """
    doctor_id = await _get_current_doctor_id(current)
    appointments = await patient_service.list_patient_appointments_for_doctor(
        patient_id=patient_id, doctor_id=doctor_id, skip=skip, limit=limit
    )
    result = []
    for ap in appointments:
        try:
            # جلب بيانات المريض والطبيب
            patient_name = None
            patient_phone = None
            doctor_name = None
            try:
                patient = await Patient.get(ap.patient_id)
                if patient:
                    user = await User.get(patient.user_id)
                    if user:
                        patient_name = user.name
                        patient_phone = user.phone  # ⭐ إضافة رقم الهاتف
                doctor = await Doctor.get(ap.doctor_id)
                if doctor:
                    user = await User.get(doctor.user_id)
                    if user:
                        doctor_name = user.name
            except Exception:
                pass
            
            result.append(
                AppointmentOut(
                    id=str(ap.id),
                    patient_id=str(ap.patient_id),
                    patient_name=patient_name,
                    patient_phone=patient_phone,  # ⭐ إضافة رقم الهاتف
                    doctor_id=str(ap.doctor_id),
                    doctor_name=doctor_name,
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
    """تحديث حالة موعد (pending, completed, cancelled, late)."""
    doctor_id = await _get_current_doctor_id(current)
    appointment = await patient_service.update_appointment_status(
        appointment_id=appointment_id,
        patient_id=patient_id,
        doctor_id=doctor_id,
        status=status_update.status,
    )
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found or unauthorized")

    # جلب بيانات المريض والطبيب
    patient_name = None
    doctor_name = None
    try:
        patient = await Patient.get(appointment.patient_id)
        if patient:
            user = await User.get(patient.user_id)
            if user:
                patient_name = user.name
        doctor = await Doctor.get(appointment.doctor_id)
        if doctor:
            user = await User.get(doctor.user_id)
            if user:
                doctor_name = user.name
    except Exception:
        pass

    return AppointmentOut(
        id=str(appointment.id),
        patient_id=str(appointment.patient_id),
        patient_name=patient_name,
        doctor_id=str(appointment.doctor_id),
        doctor_name=doctor_name,
        scheduled_at=appointment.scheduled_at.isoformat() if appointment.scheduled_at else datetime.now(timezone.utc).isoformat(),
        note=appointment.note,
        image_path=appointment.image_path,
        image_paths=getattr(appointment, 'image_paths', []) if hasattr(appointment, 'image_paths') else (([appointment.image_path] if appointment.image_path else [])),
        status=appointment.status,
    )

@router.patch("/patients/{patient_id}/appointments/{appointment_id}/datetime", response_model=AppointmentOut)
async def update_appointment_datetime(
    patient_id: str,
    appointment_id: str,
    datetime_update: AppointmentDateTimeUpdate,
    current=Depends(get_current_user),
):
    """تعديل تاريخ ووقت الموعد. يتم تحديث الموعد في كل الأماكن."""
    doctor_id = await _get_current_doctor_id(current)
    
    # تحويل ISO string إلى datetime
    try:
        scheduled_at = datetime.fromisoformat(datetime_update.scheduled_at)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid datetime format")
    
    appointment = await patient_service.update_appointment_datetime(
        appointment_id=appointment_id,
        patient_id=patient_id,
        doctor_id=doctor_id,
        scheduled_at=scheduled_at,
    )
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found or unauthorized")

    # جلب بيانات المريض والطبيب
    patient_name = None
    doctor_name = None
    try:
        patient = await Patient.get(appointment.patient_id)
        if patient:
            user = await User.get(patient.user_id)
            if user:
                patient_name = user.name
        doctor = await Doctor.get(appointment.doctor_id)
        if doctor:
            user = await User.get(doctor.user_id)
            if user:
                doctor_name = user.name
    except Exception:
        pass

    return AppointmentOut(
        id=str(appointment.id),
        patient_id=str(appointment.patient_id),
        patient_name=patient_name,
        doctor_id=str(appointment.doctor_id),
        doctor_name=doctor_name,
        scheduled_at=appointment.scheduled_at.isoformat() if appointment.scheduled_at else datetime.now(timezone.utc).isoformat(),
        note=appointment.note,
        image_path=appointment.image_path,
        image_paths=getattr(appointment, 'image_paths', []) if hasattr(appointment, 'image_paths') else (([appointment.image_path] if appointment.image_path else [])),
        status=appointment.status,
    )
