from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Tuple
from fastapi import HTTPException
from beanie import PydanticObjectId as OID
from beanie.operators import In, NotIn, And, Or

from app.models import Patient, DoctorPatientProfile, User, Doctor, Appointment, TreatmentNote, GalleryImage
from app.constants import Role
from app.schemas import PatientUpdate

# نرفع الحد الأقصى للصفحات إلى رقم كبير حتى لا نقيد النتائج بشكل قوي
MAX_PAGE_SIZE = 100000


def _normalize_pagination(skip: int = 0, limit: Optional[int] = None) -> Tuple[int, Optional[int]]:
    """Ensure pagination params stay within safe bounds."""
    safe_skip = max(0, skip)
    if limit is None:
        return safe_skip, None
    safe_limit = max(1, min(limit, MAX_PAGE_SIZE))
    return safe_skip, safe_limit


async def _attach_users(patients: List[Patient]) -> None:
    """Attach User documents to patient objects for legacy attributes."""
    if not patients:
        return
    user_ids = list({p.user_id for p in patients if p.user_id})
    if not user_ids:
        return
    users = await User.find(In(User.id, user_ids)).to_list()
    user_map = {u.id: u for u in users}
    for patient in patients:
        setattr(patient, "user", user_map.get(patient.user_id))


def _to_utc(dt: datetime) -> datetime:
    """Normalize a datetime to UTC, adding tzinfo if needed."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _same_utc_day(a: datetime, b: datetime) -> bool:
    """مقارنة تاريخين بعد تحويلهما إلى UTC على مستوى اليوم فقط (بدون وقت)."""
    au = _to_utc(a)
    bu = _to_utc(b)
    return au.date() == bu.date()


def _reset_doctor_profile_assignment(patient: Patient, doctor_id: str, assigned_at: datetime | None = None) -> DoctorPatientProfile:
    """Initialize or reset the profile entry when a doctor is newly assigned."""
    key = str(doctor_id)
    now = assigned_at or datetime.now(timezone.utc)
    profile = patient.doctor_profiles.get(key)
    if profile is None:
        profile = DoctorPatientProfile(
            assigned_at=now,
        )
    else:
        profile.assigned_at = now
    # عند كل تحويل جديد، نعيد تعيين آخر نشاط لهذا الطبيب على هذا المريض
    profile.last_action_at = None
    profile.active_on_assigned_day = False
    patient.doctor_profiles[key] = profile
    return profile


def _touch_doctor_last_action(patient: Patient, doctor_id: str) -> None:
    """
    Deprecated: لم نعد نعتمد نشاط الطبيب بالإجراءات لتفعيل/إلغاء تفعيل المرضى.
    """
    return

async def get_patient_by_id(patient_id: str) -> Tuple[Patient, User]:
    """Fetch patient and its user info or 404."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    user = await User.get(patient.user_id)
    return patient, user

async def list_doctor_patients(doctor_id: str, skip: int = 0, limit: Optional[int] = None) -> List[Patient]:
    """All patients assigned to this doctor (via doctor_ids list)."""
    skip, limit = _normalize_pagination(skip, limit)
    try:
        did = OID(doctor_id)
    except Exception as e:
        print(f"❌ Error converting doctor_id to OID: {doctor_id}, error: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid doctor_id format: {doctor_id}")

    doctor_key = str(did)
    try:
        # Return all patients that have this doctor in doctor_ids
        filter_query = {
            "doctor_ids": {"$in": [did]},
        }
        query = Patient.find(filter_query).skip(skip)
        if limit is not None:
            query = query.limit(limit)
        else:
            query = query.limit(MAX_PAGE_SIZE)
        patients = await query.to_list()
        return patients
    except Exception as e:
        print(f"❌ Error in list_doctor_patients: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error fetching patients: {str(e)}")


async def cleanup_inactive_new_patients_for_doctor(doctor_id: str) -> int:
    """
    تحويل المرضى الجدد غير المُفعّلين إلى "inactive" وإزالتهم من حساب الطبيب.

    المنطق:
    - نركّز فقط على المرضى الذين نوع زيارتهم \"مريض جديد\".
    - نطبّق فقط على المرضى الذين activity_status == \"pending\".
    - إذا انتهى يوم التحويل ولم يفعّله موظف الاستقبال، نعتبره \"inactive\".
    - عند التحويل إلى inactive:
      * حذف جميع الأطباء من doctor_ids (المريض يخرج من حسابات الأطباء)
      * تفريغ doctor_profiles
      * إضافة InactivePatientLog لكل طبيب كان مرتبطاً بالمريض (للإحصائيات)
    """
    try:
        did = OID(doctor_id)
    except Exception as e:
        print(f"❌ Error converting doctor_id to OID in cleanup_inactive_new_patients_for_doctor: {doctor_id}, error: {e}")
        return 0

    now = datetime.now(timezone.utc)
    removed_count = 0
    doctor_key = str(did)

    try:
        # نستهدف فقط المرضى الجدد المرتبطين بهذا الطبيب وبحالة pending
        patients = await Patient.find(
            {
                "doctor_ids": {"$in": [did]},
                "visit_type": "مريض جديد",
                "activity_status": "pending",
            }
        ).to_list()

        for patient in patients:
            profiles = patient.doctor_profiles or {}
            profile = profiles.get(doctor_key)
            # fallback: إذا لا يوجد assigned_at للطبيب، نعتمد created_at للمريض
            assigned_at = (
                profile.assigned_at
                if profile and getattr(profile, "assigned_at", None)
                else getattr(patient, "created_at", None)
            )
            if not assigned_at:
                continue

            assigned_utc = _to_utc(assigned_at)
            day_start = assigned_utc.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)

            # لم ينتهِ يوم التحويل بعد -> لا نتخذ قرار الآن
            if now < day_end:
                continue

            # ما زال pending بعد انتهاء يوم التحويل => inactive
            removed_doctors = list(patient.doctor_ids or [])
            if not removed_doctors:
                continue

            from app.models import InactivePatientLog
            for removed_doctor_id in removed_doctors:
                try:
                    removed_doctor_key = str(removed_doctor_id)
                    removed_profile = profiles.get(removed_doctor_key)
                    original_assigned_at = (
                        removed_profile.assigned_at
                        if removed_profile and getattr(removed_profile, "assigned_at", None)
                        else assigned_at
                    )
                    await InactivePatientLog(
                        patient_id=patient.id,
                        doctor_id=removed_doctor_id,
                        removed_at=now,
                        original_assigned_at=original_assigned_at,
                    ).insert()
                except Exception as log_error:
                    print(
                        f"⚠️ Warning: Failed to create InactivePatientLog for patient {patient.id}, doctor {removed_doctor_id}: {log_error}"
                    )

            patient.doctor_ids = []
            patient.doctor_profiles = {}
            patient.activity_status = "inactive"
            patient.inactivated_at = now

            await patient.save()
            removed_count += 1

        if removed_count:
            print(
                f"✅ [cleanup_inactive_new_patients_for_doctor] Marked {removed_count} pending new patients as inactive for doctor {doctor_id}"
            )
        return removed_count
    except Exception as e:
        print(f"❌ Error in cleanup_inactive_new_patients_for_doctor: {e}")
        import traceback
        traceback.print_exc()
        return 0


async def cleanup_inactive_new_patients_global() -> int:
    """
    تنظيف عام: تحويل كل المرضى الجدد pending الذين انتهى يوم إضافتهم إلى inactive
    وحذفهم من حسابات الأطباء مع تسجيل InactivePatientLog.
    """
    now = datetime.now(timezone.utc)
    removed_count = 0

    try:
        patients = await Patient.find(
            {
                "visit_type": "مريض جديد",
                "activity_status": "pending",
                "doctor_ids.0": {"$exists": True},
            }
        ).to_list()

        from app.models import InactivePatientLog

        for patient in patients:
            profiles = patient.doctor_profiles or {}
            reference_dt = getattr(patient, "created_at", None)

            # إذا توفرت assigned_at لأي طبيب، نأخذ الأقدم كبداية للحساب
            assigned_values: List[datetime] = []
            for profile in profiles.values():
                if profile and getattr(profile, "assigned_at", None):
                    assigned_values.append(_to_utc(profile.assigned_at))
            if assigned_values:
                reference_dt = min(assigned_values)

            if not reference_dt:
                continue

            reference_utc = _to_utc(reference_dt)
            day_start = reference_utc.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            if now < day_end:
                continue

            removed_doctors = list(patient.doctor_ids or [])
            if not removed_doctors:
                continue

            for removed_doctor_id in removed_doctors:
                try:
                    removed_doctor_key = str(removed_doctor_id)
                    removed_profile = profiles.get(removed_doctor_key)
                    original_assigned_at = (
                        removed_profile.assigned_at
                        if removed_profile and getattr(removed_profile, "assigned_at", None)
                        else reference_utc
                    )
                    await InactivePatientLog(
                        patient_id=patient.id,
                        doctor_id=removed_doctor_id,
                        removed_at=now,
                        original_assigned_at=original_assigned_at,
                    ).insert()
                except Exception as log_error:
                    print(
                        f"⚠️ Warning: Failed to create InactivePatientLog for patient {patient.id}, doctor {removed_doctor_id}: {log_error}"
                    )

            patient.doctor_ids = []
            patient.doctor_profiles = {}
            patient.activity_status = "inactive"
            patient.inactivated_at = now
            await patient.save()
            removed_count += 1

        if removed_count:
            print(
                f"✅ [cleanup_inactive_new_patients_global] Marked {removed_count} pending new patients as inactive"
            )
        return removed_count
    except Exception as e:
        print(f"❌ Error in cleanup_inactive_new_patients_global: {e}")
        import traceback
        traceback.print_exc()
        return 0


async def activate_patient_by_reception(*, patient_id: str) -> Patient:
    """
    تفعيل المريض من موظف الاستقبال:
    pending -> active
    """
    return await update_patient_activity_status_by_reception(
        patient_id=patient_id,
        status="active",
    )


async def update_patient_activity_status_by_reception(*, patient_id: str, status: str) -> Patient:
    """
    تحديث حالة المريض من واجهة الاستقبال:
    - pending: مسموح فقط في يوم إنشاء المريض.
    - active: إذا كان inactive ولا يوجد أي طبيب مرتبط -> مرفوض حتى يتم تحويله لطبيب أولاً.
    - inactive: يحذف ارتباطات الأطباء ويضيف InactivePatientLog لكل طبيب مرتبط.
    """
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    normalized = (status or "").strip().lower()
    if normalized not in {"pending", "active", "inactive"}:
        raise HTTPException(status_code=400, detail="Invalid status. Allowed: pending, active, inactive")

    now = datetime.now(timezone.utc)
    created_at = _to_utc(getattr(patient, "created_at", now))
    created_day_end = created_at.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)

    if normalized == "pending":
        # الحالة pending مخصصة ليوم الإنشاء فقط للمريض الجديد.
        if now >= created_day_end:
            raise HTTPException(
                status_code=400,
                detail="لا يمكن إرجاع المريض إلى قيد الانتظار بعد انتهاء يوم إنشائه",
            )
        patient.activity_status = "pending"
        patient.activated_at = None
        patient.inactivated_at = None
        await patient.save()
        return patient

    if normalized == "active":
        if not (patient.doctor_ids or []):
            raise HTTPException(
                status_code=400,
                detail="لا يمكن تحويل الحالة إلى نشط بدون تحويل المريض إلى طبيب",
            )
        patient.activity_status = "active"
        patient.activated_at = now
        patient.inactivated_at = None
        await patient.save()
        return patient

    # normalized == "inactive"
    removed_doctors = list(patient.doctor_ids or [])
    profiles = patient.doctor_profiles or {}

    if removed_doctors:
        from app.models import InactivePatientLog

        for removed_doctor_id in removed_doctors:
            try:
                removed_doctor_key = str(removed_doctor_id)
                removed_profile = profiles.get(removed_doctor_key)
                original_assigned_at = (
                    removed_profile.assigned_at
                    if removed_profile and getattr(removed_profile, "assigned_at", None)
                    else now
                )
                await InactivePatientLog(
                    patient_id=patient.id,
                    doctor_id=removed_doctor_id,
                    removed_at=now,
                    original_assigned_at=original_assigned_at,
                ).insert()
            except Exception as log_error:
                print(
                    f"⚠️ Warning: Failed to create InactivePatientLog for patient {patient.id}, doctor {removed_doctor_id}: {log_error}"
                )

    patient.activity_status = "inactive"
    patient.inactivated_at = now
    patient.doctor_ids = []
    patient.doctor_profiles = {}
    await patient.save()
    return patient



async def update_patient_by_doctor(*, doctor_id: str, patient_id: str, data: PatientUpdate) -> Patient:
    """يسمح للطبيب بتعديل بيانات المريض إن كان من مرضاه (في doctor_ids)."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    u = await User.get(patient.user_id)
    if data.name is not None:
        u.name = data.name
    if data.gender is not None:
        u.gender = data.gender
    if data.age is not None:
        u.age = data.age
    if data.city is not None:
        u.city = data.city
    if data.treatment_type is not None:
        patient.treatment_type = data.treatment_type
    if data.consultation_type is not None:
        patient.consultation_type = data.consultation_type
    if data.payment_methods is not None:
        patient.payment_methods = data.payment_methods
    await u.save()
    await patient.save()
    return patient

async def update_patient_by_admin(*, patient_id: str, data: PatientUpdate) -> Patient:
    """المدير يعدّل بيانات أي مريض (بما فيها الهاتف مع التحقق من التفرّد)."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    u = await User.get(patient.user_id)
    if data.phone is not None and data.phone != u.phone:
        if await User.find_one(User.phone == data.phone):
            raise HTTPException(status_code=400, detail="Phone already exists")
        u.phone = data.phone
    if data.name is not None:
        u.name = data.name
    if data.gender is not None:
        u.gender = data.gender
    if data.age is not None:
        u.age = data.age
    if data.city is not None:
        u.city = data.city
    if data.treatment_type is not None:
        patient.treatment_type = data.treatment_type
    if data.consultation_type is not None:
        patient.consultation_type = data.consultation_type
    if data.payment_methods is not None:
        patient.payment_methods = data.payment_methods
    await u.save()
    await patient.save()
    return patient

async def delete_patient(*, actor_role: Role, patient_id: str, actor_doctor_id: str | None = None) -> None:
    """حذف مريض: المدير دائمًا، والطبيب فقط إن كان من مرضاه."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if actor_role == Role.DOCTOR:
        if actor_doctor_id and OID(actor_doctor_id) not in patient.doctor_ids:
            raise HTTPException(status_code=403, detail="Not your patient")
    user = await User.get(patient.user_id)
    if user:
        await user.delete()
    return None

async def assign_patient_doctors(
    *,
    patient_id: str,
    doctor_ids: List[str],
    assigned_by_user_id: Optional[str] = None,
) -> Patient:
    """Receptionist/Admin can assign multiple doctors for a patient and نسجل التحويلات."""
    from app.models import AssignmentLog
    from app.models import InactivePatientLog
    from beanie.operators import In

    print(f"🔗 [assign_patient_doctors] patient_id: {patient_id}, doctor_ids: {doctor_ids}")

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    # Validate all doctors exist
    doctor_oids = []
    for doctor_id in doctor_ids:
        doctor = await Doctor.get(OID(doctor_id))
        if doctor is None:
            print(f"❌ [assign_patient_doctors] Doctor {doctor_id} not found")
            raise HTTPException(status_code=404, detail=f"Doctor {doctor_id} not found")
        doctor_oids.append(OID(doctor_id))
        print(f"✅ [assign_patient_doctors] Doctor {doctor_id} found")

    prev_doctor_ids = set(patient.doctor_ids)
    new_doctor_ids = set(doctor_oids)

    print(f"📋 [assign_patient_doctors] Previous doctor_ids: {prev_doctor_ids}")
    print(f"📋 [assign_patient_doctors] Setting doctor_ids to: {new_doctor_ids}")

    # Update doctor_ids
    patient.doctor_ids = doctor_oids

    print(f"💾 [assign_patient_doctors] patient.doctor_ids set to: {patient.doctor_ids}")

    # سجل التحويلات عند التغيير
    # للأطباء الجدد (المضافين)
    #
    # ملاحظة مهمة:
    # إذا كان المريض حالته inactive وتمت إعادته لنفس الطبيب الذي كان مرتبطاً به سابقاً
    # (restore)، فلا نعتبر ذلك "تحويلاً جديداً" ولا ننشئ AssignmentLog.
    # بذلك يبقى عداد التحويلات مستقلاً عن تغييرات الحالة.
    added_doctors = new_doctor_ids - prev_doctor_ids
    assignment_time = datetime.now(timezone.utc)
    restored_doctors: set[OID] = set()
    if added_doctors and (patient.activity_status or "").lower() == "inactive":
        previous_inactive_logs = await InactivePatientLog.find(
            InactivePatientLog.patient_id == patient.id,
            In(InactivePatientLog.doctor_id, list(added_doctors)),
        ).to_list()
        restored_doctors = {log.doctor_id for log in previous_inactive_logs if getattr(log, "doctor_id", None)}

    for doctor_id in added_doctors:
        if doctor_id in restored_doctors:
            print(
                f"ℹ️ [assign_patient_doctors] Skip AssignmentLog for restored inactive patient {patient.id} to previous doctor {doctor_id}"
            )
        else:
            print(f"📝 [assign_patient_doctors] Creating AssignmentLog for newly added doctor {doctor_id}")
            await AssignmentLog(
                patient_id=patient.id,
                doctor_id=doctor_id,
                previous_doctor_id=None,
                assigned_by_user_id=OID(assigned_by_user_id) if assigned_by_user_id else None,
                kind="assigned",
            ).insert()
        _reset_doctor_profile_assignment(patient, str(doctor_id), assigned_at=assignment_time)
    
    # للأطباء المزالين: لا ننشئ InactivePatientLog هنا.
    # السجل يُنشأ فقط عند انتقال المريض من pending إلى inactive تلقائياً.
    removed_doctors = prev_doctor_ids - new_doctor_ids
    if removed_doctors:
        print(
            f"ℹ️ [assign_patient_doctors] Removed doctors for patient {patient.id}: {list(removed_doctors)} (no inactive logs on manual removal)"
        )

    # إعادة الحالة إلى pending عند وجود ربط جديد لطبيب لمريض جديد.
    if patient.visit_type == "مريض جديد" and added_doctors and patient.activity_status != "active":
        patient.activity_status = "pending"
        patient.activated_at = None
        patient.inactivated_at = None

    print(f"💾 [assign_patient_doctors] Saving patient...")
    await patient.save()
    print(f"✅ [assign_patient_doctors] Patient saved. doctor_ids: {patient.doctor_ids}")
    
    # التحقق من الحفظ
    saved_patient = await Patient.get(patient.id)
    print(f"🔍 [assign_patient_doctors] Verification - saved patient doctor_ids: {saved_patient.doctor_ids}")
    
    return patient

async def set_treatment_type(*, patient_id: str, doctor_id: str, treatment_type: str) -> Patient:
    """Doctor sets the treatment type for their patient."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    # لا نستخدم بعد الآن الحقل العام patient.treatment_type لعزل نوع العلاج لكل طبيب على حدة.
    # بدلاً من ذلك نخزّنه فقط داخل doctor_profiles[doctor_id].treatment_type
    doctor_key = str(doctor_id)
    profile = patient.doctor_profiles.get(doctor_key)
    if profile:
        profile.treatment_type = treatment_type
    else:
        profile = DoctorPatientProfile(treatment_type=treatment_type)
    patient.doctor_profiles[doctor_key] = profile

    patient.doctor_profiles[doctor_key] = profile
    await patient.save()
    
    # إذا كان نوع العلاج "زراعة"، نقوم بتهيئة المراحل تلقائياً
    if treatment_type == "زراعة":
        try:
            from app.services.implant_stage_service import initialize_implant_stages
            # الحصول على تاريخ تسجيل المريض من User
            user = await User.get(patient.user_id)
            if user and user.created_at:
                registration_date = user.created_at
            else:
                # إذا لم يكن هناك تاريخ، نستخدم التاريخ الحالي
                registration_date = datetime.now(timezone.utc)
            await initialize_implant_stages(patient_id, registration_date, doctor_id)
        except Exception as e:
            # لا نرفض العملية إذا فشلت تهيئة المراحل
            print(f"⚠️ Warning: Failed to initialize implant stages: {e}")
    
    return patient


async def set_payment_methods(*, patient_id: str, doctor_id: str, methods: List[str]) -> Patient:
    """
    تحديد طرق الدفع للمريض من قبل الطبيب.
    - يمكن اختيار طريقة أو أكثر (مثلاً: نقد، ماستر كارد، كمبيالة، تعهد).
    - يعتبر هذا الإجراء نشاطاً على المريض (يحدّث last_action_at).
    """
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")

    doctor_key = str(doctor_id)
    profile = patient.doctor_profiles.get(doctor_key)
    if profile is None:
        profile = DoctorPatientProfile()
    profile.payment_methods = methods
    patient.doctor_profiles[doctor_key] = profile

    await patient.save()
    return patient

async def create_note(
    *, patient_id: str, doctor_id: str, note: Optional[str], image_path: Optional[str] = None, image_paths: Optional[List[str]] = None
) -> TreatmentNote:
    """Add a new treatment note (section 1) with optional images; date auto."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    # للتوافق مع البيانات القديمة، نستخدم أول صورة كـ image_path
    final_image_path = image_path
    final_image_paths = image_paths or []
    if final_image_paths and not final_image_path:
        final_image_path = final_image_paths[0]
    
    tn = TreatmentNote(
        patient_id=patient.id,
        doctor_id=OID(doctor_id),
        note=note,
        image_path=final_image_path,
        image_paths=final_image_paths
    )
    await tn.insert()

    await patient.save()
    return tn

async def update_note(
    *, patient_id: str, note_id: str, doctor_id: str, note: Optional[str] = None, image_paths: Optional[List[str]] = None
) -> TreatmentNote:
    """Update an existing treatment note."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    tn = await TreatmentNote.get(OID(note_id))
    if not tn:
        raise HTTPException(status_code=404, detail="Note not found")
    if str(tn.patient_id) != patient_id:
        raise HTTPException(status_code=403, detail="Note does not belong to this patient")
    if str(tn.doctor_id) != doctor_id:
        raise HTTPException(status_code=403, detail="Not your note")
    
    if note is not None:
        tn.note = note
    if image_paths is not None:
        # إذا كانت القائمة فارغة، نحتفظ بالصور القديمة
        if len(image_paths) > 0:
            tn.image_paths = image_paths
            # للتوافق مع البيانات القديمة
            tn.image_path = image_paths[0] if image_paths else None

    await patient.save()

    await tn.save()
    return tn

async def delete_note(
    *, patient_id: str, note_id: str, doctor_id: str
) -> bool:
    """Delete a treatment note."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    tn = await TreatmentNote.get(OID(note_id))
    if not tn:
        raise HTTPException(status_code=404, detail="Note not found")
    if str(tn.patient_id) != patient_id:
        raise HTTPException(status_code=403, detail="Note does not belong to this patient")
    if str(tn.doctor_id) != doctor_id:
        raise HTTPException(status_code=403, detail="Not your note")
    
    await tn.delete()

    await patient.save()

    return True

async def create_gallery_image(
    *,
    patient_id: str,
    uploaded_by_user_id: str,
    image_path: str,
    note: Optional[str],
    doctor_id: str | None = None,
) -> GalleryImage:
    """
    إنشاء سجل صورة في معرض المريض.

    - uploaded_by_user_id: المستخدم (طبيب / استقبال / مصور) الذي رفع الصورة.
    - doctor_id: يتم تمريره فقط عندما تكون الصورة مرفوعة من قبل الطبيب لحساب النشاط.
    """
    doctor_oid = OID(doctor_id) if doctor_id else None
    gi = GalleryImage(
        patient_id=OID(patient_id),
        uploaded_by_user_id=OID(uploaded_by_user_id),
        image_path=image_path,
        note=note,
        doctor_id=doctor_oid,
    )
    await gi.insert()

    # لا نربط النشاط بحفظ الصور ضمن آلية تفعيل المرضى الجديدة.
    if doctor_id:
        pass

    return gi

async def delete_gallery_image(*, gallery_image_id: str, patient_id: str, doctor_id: str | None = None) -> bool:
    """حذف صورة من المعرض. يتحقق من أن الصورة تخص المريض المحدد."""
    try:
        gi = await GalleryImage.get(OID(gallery_image_id))
        if not gi:
            raise HTTPException(status_code=404, detail="Gallery image not found")
        
        # Verify it belongs to the patient
        if str(gi.patient_id) != patient_id:
            raise HTTPException(status_code=403, detail="Gallery image does not belong to this patient")
        if doctor_id:
            if not gi.doctor_id or str(gi.doctor_id) != doctor_id:
                raise HTTPException(status_code=403, detail="Not your gallery image")

        await gi.delete()

        # لا نربط حذف الصورة بآلية تفعيل المرضى.
        if doctor_id:
            pass

        return True
    except Exception as e:
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(status_code=500, detail=f"Failed to delete gallery image: {str(e)}")

async def create_appointment(
    *, patient_id: str, doctor_id: str, scheduled_at: datetime, note: Optional[str], image_path: Optional[str] = None, image_paths: Optional[List[str]] = None
) -> Appointment:
    """
    إنشاء موعد جديد للمريض.
    الموعد الجديد يأخذ حالة "pending" (قيد الانتظار) افتراضياً.
    """
    # Validate ownership
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if OID(doctor_id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")

    # للتوافق مع البيانات القديمة: إذا كانت image_paths موجودة، استخدمها، وإلا استخدم image_path
    final_image_paths = image_paths if image_paths is not None else ([image_path] if image_path else [])
    # للتوافق مع البيانات القديمة، احتفظ بأول صورة في image_path
    final_image_path = final_image_paths[0] if final_image_paths else None

    # التأكد من أن scheduled_at له timezone
    if scheduled_at.tzinfo is None:
        scheduled_at = scheduled_at.replace(tzinfo=timezone.utc)
    else:
        scheduled_at = scheduled_at.astimezone(timezone.utc)

    now = datetime.now(timezone.utc)
    ap = Appointment(
        patient_id=patient.id,
        doctor_id=OID(doctor_id),
        scheduled_at=scheduled_at,
        note=note,
        image_path=final_image_path,
        image_paths=final_image_paths,
        status="pending",  # الحالة الافتراضية: قيد الانتظار
        created_at=now,
        updated_at=now,
    )
    await ap.insert()

    await patient.save()

    # Notify patient about new appointment (push notification)
    try:
        from app.services.notification_service import notify_user

        doctor_name = None
        try:
            doctor = await Doctor.get(OID(doctor_id))
            if doctor and doctor.user_id:
                doctor_user = await User.get(doctor.user_id)
                if doctor_user:
                    doctor_name = doctor_user.name
        except Exception:
            pass

        body = (
            f"تم تحديد موعدك القادم مع الدكتور {doctor_name}"
            if doctor_name
            else "تم تحديد موعدك القادم"
        )
        await notify_user(user_id=patient.user_id, title="موعد جديد", body=body)
    except Exception:
        pass

    return ap

# ---------------------- Listings & Filters ----------------------

async def _date_bounds(day: Optional[str], date_from: Optional[datetime], date_to: Optional[datetime]) -> tuple[Optional[datetime], Optional[datetime]]:
    now = datetime.now(timezone.utc)
    if day == "today":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=1)
        return start, end
    if day == "tomorrow":
        start = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=1)
        return start, end
    if day == "month":
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        # naive month end calc
        if start.month == 12:
            end = start.replace(year=start.year+1, month=1)
        else:
            end = start.replace(month=start.month+1)
        return start, end
    return date_from, date_to

async def list_appointments_for_doctor(
    *,
    doctor_id: str,
    day: Optional[str] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[Appointment]:
    """
    جلب مواعيد الطبيب مع التصفية حسب:
    - day: "today" (اليوم), "month" (هذا الشهر)
    - date_from, date_to: تصفية حسب التاريخ
    - status: "late" (المتأخرون), "pending", "completed", "cancelled"
    
    القاعدة: المواعيد المكتملة والملغية لا تظهر في الجداول، فقط في ملف المريض.
    """
    start, end = await _date_bounds(day, date_from, date_to)
    skip, limit = _normalize_pagination(skip, limit)
    did = OID(doctor_id)
    query = Appointment.find(Appointment.doctor_id == did)
    
    if start:
        query = query.find(Appointment.scheduled_at >= start)
    if end:
        query = query.find(Appointment.scheduled_at < end)
    
    now = datetime.now(timezone.utc)
    
    if status == "late":
        # ⭐ المواعيد المتأخرة: 
        # 1. المواعيد التي حالتها late مباشرة
        # 2. المواعيد التي عبرت (scheduled_at < now) وحالتها pending أو scheduled
        query = query.find(
            Or(
                Appointment.status == "late",
                And(
                    Appointment.scheduled_at < now,
                    In(Appointment.status, ["pending", "scheduled"])
                )
            )
        )
    elif status:
        # تصفية حسب الحالة المحددة
        # للتوافق مع البيانات القديمة: إذا طلبنا "pending"، نعرض أيضاً "scheduled"
        if status == "pending":
            query = query.find(In(Appointment.status, ["pending", "scheduled"]))
        else:
            query = query.find(Appointment.status == status)
    else:
        # الافتراضي: استبعاد المواعيد المكتملة والملغية
        # نعرض فقط: pending, late, scheduled (للتوافق مع البيانات القديمة)
        query = query.find(
            And(
                Appointment.status != "completed",
                Appointment.status != "cancelled"
            )
        )
    
    # ترتيب تصاعدي: من الأقدم للأحدث
    query = query.sort(+Appointment.scheduled_at).skip(skip)
    if limit is not None:
        query = query.limit(limit)
    appointments = await query.to_list()
    
    # تحديث المواعيد القديمة من "scheduled" إلى "pending" تلقائياً
    updated_count = 0
    for apt in appointments:
        if apt.status == "scheduled":
            apt.status = "pending"
            apt.updated_at = datetime.now(timezone.utc)
            await apt.save()
            updated_count += 1
    
    if updated_count > 0:
        print(f"✅ [list_appointments_for_doctor] Updated {updated_count} appointments from 'scheduled' to 'pending'")
    
    return appointments

async def list_appointments_for_all(
    *,
    day: Optional[str] = None,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    status: Optional[str] = None,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[Appointment]:
    """
    جلب جميع المواعيد (لموظف الاستقبال) مع التصفية حسب:
    - day: "today" (اليوم), "month" (هذا الشهر)
    - date_from, date_to: تصفية حسب التاريخ
    - status: "late" (المتأخرون), "pending", "completed", "cancelled"
    
    القاعدة: المواعيد المكتملة والملغية لا تظهر في الجداول، فقط في ملف المريض.
    """
    start, end = await _date_bounds(day, date_from, date_to)
    skip, limit = _normalize_pagination(skip, limit)
    query = Appointment.find()
    
    if start:
        query = query.find(Appointment.scheduled_at >= start)
    if end:
        query = query.find(Appointment.scheduled_at < end)
    
    now = datetime.now(timezone.utc)
    
    if status == "late":
        # ⭐ المواعيد المتأخرة: 
        # 1. المواعيد التي حالتها late مباشرة
        # 2. المواعيد التي عبرت (scheduled_at < now) وحالتها pending أو scheduled
        query = query.find(
            Or(
                Appointment.status == "late",
                And(
                    Appointment.scheduled_at < now,
                    In(Appointment.status, ["pending", "scheduled"])
                )
            )
        )
    elif status:
        # تصفية حسب الحالة المحددة
        # للتوافق مع البيانات القديمة: إذا طلبنا "pending"، نعرض أيضاً "scheduled"
        if status == "pending":
            query = query.find(In(Appointment.status, ["pending", "scheduled"]))
        else:
            query = query.find(Appointment.status == status)
    else:
        # الافتراضي: استبعاد المواعيد المكتملة والملغية
        # نعرض فقط: pending, late
        query = query.find(
            And(
                Appointment.status != "completed",
                Appointment.status != "cancelled"
            )
        )
    
    # ترتيب تصاعدي: من الأقدم للأحدث
    query = query.sort(+Appointment.scheduled_at).skip(skip)
    if limit is not None:
        query = query.limit(limit)
    appointments = await query.to_list()
    
    # تحديث المواعيد القديمة من "scheduled" إلى "pending" تلقائياً
    updated_count = 0
    for apt in appointments:
        if apt.status == "scheduled":
            apt.status = "pending"
            apt.updated_at = datetime.now(timezone.utc)
            await apt.save()
            updated_count += 1
    
    if updated_count > 0:
        print(f"✅ [list_appointments_for_all] Updated {updated_count} appointments from 'scheduled' to 'pending'")
    
    return appointments

async def delete_appointment(*, appointment_id: str, patient_id: str, doctor_id: str) -> bool:
    """حذف موعد للمريض."""
    try:
        appointment = await Appointment.get(OID(appointment_id))
        if not appointment:
            return False
        # التحقق من أن الموعد يخص المريض المحدد
        if str(appointment.patient_id) != patient_id:
            return False
        if str(appointment.doctor_id) != doctor_id:
            return False

        await appointment.delete()

        # لا نربط حذف الموعد بآلية تفعيل المرضى.
        try:
            patient = await Patient.get(OID(patient_id))
            if patient:
                await patient.save()
        except Exception:
            pass

        return True
    except Exception as e:
        print(f"Error deleting appointment {appointment_id}: {e}")
        return False

async def update_appointment_status(
    *, appointment_id: str, patient_id: str, doctor_id: str, status: str
) -> Appointment | None:
    """
    تحديث حالة الموعد.
    الحالات: pending, completed, cancelled, late
    - completed: يختفي من الجداول، يبقى في ملف المريض
    - cancelled: يختفي من الجداول، يبقى في ملف المريض
    - pending: يظهر في الجداول وملف المريض
    - late: يظهر في تبويب المتأخرين
    """
    try:
        appointment = await Appointment.get(OID(appointment_id))
        if not appointment:
            return None
        # التحقق من أن الموعد يخص المريض والطبيب المحددين
        if str(appointment.patient_id) != patient_id:
            return None
        if str(appointment.doctor_id) != doctor_id:
            return None
        # التحقق من أن الطبيب في قائمة أطباء المريض
        patient = await Patient.get(OID(patient_id))
        if patient and OID(doctor_id) not in patient.doctor_ids:
            return None
        
        status_lower = status.lower()
        # التحقق من صحة الحالة
        valid_statuses = ["pending", "completed", "cancelled", "late"]
        if status_lower not in valid_statuses:
            return None
        
        # تحديث الحالة
        appointment.status = status_lower
        appointment.updated_at = datetime.now(timezone.utc)
        await appointment.save()

        if patient:
            await patient.save()

        return appointment
    except Exception as e:
        print(f"Error updating appointment status {appointment_id}: {e}")
        return None

async def update_appointment_datetime(
    *, appointment_id: str, patient_id: str, doctor_id: str, scheduled_at: datetime
) -> Appointment | None:
    """
    تعديل تاريخ ووقت الموعد.
    عند التعديل، يتم حفظ التاريخ القديم في previous_scheduled_at
    ويتم تحديث الموعد في كل الأماكن.
    """
    try:
        appointment = await Appointment.get(OID(appointment_id))
        if not appointment:
            return None
        # التحقق من أن الموعد يخص المريض والطبيب المحددين
        if str(appointment.patient_id) != patient_id:
            return None
        if str(appointment.doctor_id) != doctor_id:
            return None
        # التحقق من أن الطبيب في قائمة أطباء المريض
        patient = await Patient.get(OID(patient_id))
        if patient and OID(doctor_id) not in patient.doctor_ids:
            return None
        
        # التأكد من أن scheduled_at له timezone
        if scheduled_at.tzinfo is None:
            scheduled_at = scheduled_at.replace(tzinfo=timezone.utc)
        else:
            scheduled_at = scheduled_at.astimezone(timezone.utc)
        
        # حفظ التاريخ القديم
        appointment.previous_scheduled_at = appointment.scheduled_at
        # تحديث التاريخ الجديد
        appointment.scheduled_at = scheduled_at
        appointment.updated_at = datetime.now(timezone.utc)
        
        # إذا كان الموعد متأخراً وأصبح في المستقبل، نعيد الحالة إلى pending
        now = datetime.now(timezone.utc)
        if appointment.status == "late" and scheduled_at >= now:
            appointment.status = "pending"

        await appointment.save()

        # لا نربط تعديل الموعد بآلية تفعيل المرضى.
        if patient:
            await patient.save()

        return appointment
    except Exception as e:
        print(f"Error updating appointment datetime {appointment_id}: {e}")
        return None

async def update_late_appointments() -> int:
    """
    تحديث المواعيد المتأخرة تلقائياً.
    المواعيد التي عبرت وحالتها لا تزال pending تصبح late.
    يُستدعى هذه الدالة بشكل دوري (مثلاً كل ساعة).
    """
    try:
        now = datetime.now(timezone.utc)
        # جلب جميع المواعيد التي عبرت وحالتها pending
        late_appointments = await Appointment.find(
            And(
                Appointment.scheduled_at < now,
                Appointment.status == "pending"
            )
        ).to_list()
        
        updated_count = 0
        for appointment in late_appointments:
            appointment.status = "late"
            appointment.updated_at = now
            await appointment.save()
            updated_count += 1
        
        return updated_count
    except Exception as e:
        print(f"Error updating late appointments: {e}")
        return 0

async def list_patient_appointments_grouped(*, patient_id: str) -> tuple[List[Appointment], List[Appointment]]:
    """
    جلب جميع مواعيد المريض (لحساب المريض).
    يعرض جميع المواعيد بما فيها المكتملة والملغية.
    Group appointments by doctor. Returns (appointments_for_first_doctor, all_other_appointments).
    """
    p = await Patient.get(OID(patient_id))
    if not p:
        return [], []
    # ترتيب تصاعدي: من الأقدم للأحدث
    # في حساب المريض نعرض جميع المواعيد (بما فيها المكتملة والملغية)
    apps = await Appointment.find(Appointment.patient_id == p.id).sort(+Appointment.scheduled_at).to_list()
    if not p.doctor_ids:
        return [], apps  # No doctors assigned, return all as "other"
    
    first_doctor_id = p.doctor_ids[0]
    first_doctor_appointments = []
    other_appointments = []
    
    for a in apps:
        if a.doctor_id == first_doctor_id:
            first_doctor_appointments.append(a)
        elif a.doctor_id in p.doctor_ids:
            other_appointments.append(a)
        else:
            # Appointment with doctor not in patient's doctor_ids list
            other_appointments.append(a)
    
    return first_doctor_appointments, other_appointments


async def list_patient_appointments_for_doctor(
    *, patient_id: str, doctor_id: str, skip: int = 0, limit: Optional[int] = None
) -> List[Appointment]:
    """
    جلب مواعيد المريض في ملف المريض في حساب الطبيب.
    يعرض جميع المواعيد بما فيها المكتملة والملغية.
    """
    skip, limit = _normalize_pagination(skip, limit)
    patient = await Patient.get(OID(patient_id))
    if not patient:
        return []
    if OID(doctor_id) not in patient.doctor_ids:
        return []

    # ترتيب تصاعدي: من الأقدم للأحدث
    # في ملف المريض نعرض جميع المواعيد (بما فيها المكتملة والملغية)
    query = Appointment.find(
        Appointment.patient_id == patient.id,
        Appointment.doctor_id == OID(doctor_id),
    ).sort(+Appointment.scheduled_at).skip(skip)

    if limit is not None:
        query = query.limit(limit)
    return await query.to_list()

async def list_notes_for_patient(*, patient_id: str, skip: int = 0, limit: Optional[int] = None, doctor_id: str | None = None) -> List[TreatmentNote]:
    skip, limit = _normalize_pagination(skip, limit)
    query = TreatmentNote.find(TreatmentNote.patient_id == OID(patient_id)).sort("-created_at").skip(skip)
    if doctor_id:
        query = query.find(TreatmentNote.doctor_id == OID(doctor_id))
    if limit is not None:
        query = query.limit(limit)
    return await query.to_list()

async def list_gallery_for_patient(
    *,
    patient_id: str,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[GalleryImage]:
    """
    إرجاع جميع صور المعرض لمريض معيّن بدون أية فلاتر بحسب الرافع.

    تُستخدم هذه الدالة للأدمن أو في الخدمات الداخلية.
    """
    skip, limit = _normalize_pagination(skip, limit)
    query = GalleryImage.find(GalleryImage.patient_id == OID(patient_id)).sort("-created_at").skip(skip)
    if limit is not None:
        query = query.limit(limit)
    return await query.to_list()


async def list_gallery_for_patient_public(
    *,
    patient_id: str,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[GalleryImage]:
    """
    صور المعرض كما يراها المريض.

    - لا نعرض الصور التي رفعها الأطباء أو موظفو الاستقبال.
    - حاليًا نسمح فقط بصور المصوّر (PHOTOGRAPHER)، ويمكن توسيعها لاحقًا.
    """
    skip, limit = _normalize_pagination(skip, limit)
    pid = OID(patient_id)
    # جميع الصور للمريض
    images = await GalleryImage.find(GalleryImage.patient_id == pid).sort("-created_at").to_list()
    if not images:
        return []

    # جمع معرّفات الرافعين
    uploader_ids = {img.uploaded_by_user_id for img in images if img.uploaded_by_user_id}
    if not uploader_ids:
        return []

    users = await User.find(In(User.id, list(uploader_ids))).to_list()
    user_map: dict[OID, User] = {u.id: u for u in users}

    allowed: list[GalleryImage] = []
    for img in images:
        u = user_map.get(img.uploaded_by_user_id)
        if not u:
            continue
        # المريض لا يرى صور الأطباء أو الاستقبال
        if u.role in (Role.DOCTOR, Role.RECEPTIONIST):
            continue
        # يسمح حاليًا بصور المصوّر أو أدوار أخرى غير الطبيب/الاستقبال
        allowed.append(img)

    # تطبيق الـ pagination بعد الفلترة
    if skip:
        allowed = allowed[skip:]
    if limit is not None:
        allowed = allowed[:limit]
    return allowed


async def list_gallery_for_doctor_view(
    *,
    patient_id: str,
    doctor_id: str,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[GalleryImage]:
    """
    صور المعرض كما يراها الطبيب:
    - يرى الصور التي رفعها هو نفسه (doctor_id == current_doctor_id).
    - يرى كذلك الصور التي رفعها موظفو الاستقبال لهذا المريض.
    - لا يرى الصور التي رفعها أطباء آخرون لهذا المريض.
    """
    skip, limit = _normalize_pagination(skip, limit)
    try:
        pid = OID(patient_id)
        did = OID(doctor_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid id format: {e}")

    # 1) صور هذا الطبيب
    doctor_images = await GalleryImage.find(
        GalleryImage.patient_id == pid,
        GalleryImage.doctor_id == did,
    ).to_list()

    # 2) صور الاستقبال (نحددهم عبر دور المستخدم)
    receptionist_users = await User.find(User.role == Role.RECEPTIONIST).to_list()
    rec_ids = [u.id for u in receptionist_users]
    receptionist_images: list[GalleryImage] = []
    if rec_ids:
        receptionist_images = await GalleryImage.find(
            GalleryImage.patient_id == pid,
            In(GalleryImage.uploaded_by_user_id, rec_ids),
        ).to_list()

    combined = doctor_images + receptionist_images
    # إزالة التكرارات إن وجدت
    seen: set[str] = set()
    unique: list[GalleryImage] = []
    for img in combined:
        key = str(img.id)
        if key in seen:
            continue
        seen.add(key)
        unique.append(img)

    # ترتيب تنازلي حسب created_at
    unique.sort(key=lambda x: x.created_at or datetime.now(timezone.utc), reverse=True)

    if skip:
        unique = unique[skip:]
    if limit is not None:
        unique = unique[:limit]
    return unique


async def list_gallery_for_patient_by_uploader(
    *,
    patient_id: str,
    uploaded_by_user_id: str,
    skip: int = 0,
    limit: Optional[int] = None,
) -> List[GalleryImage]:
    """
    إرجاع صور المعرض التي قام مستخدم معيّن برفعها لمريض محدّد.

    تُستخدم هذه الدالة لموظف الاستقبال (أو أي دور آخر) عندما نريد
    أن يرى فقط الصور التي قام برفعها بنفسه للمريض.
    """
    skip, limit = _normalize_pagination(skip, limit)
    try:
        pid = OID(patient_id)
        uid = OID(uploaded_by_user_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid id format: {e}")

    query = GalleryImage.find(
        GalleryImage.patient_id == pid,
        GalleryImage.uploaded_by_user_id == uid,
    ).sort("-created_at").skip(skip)
    if limit is not None:
        query = query.limit(limit)
    return await query.to_list()


async def get_patient_activity_summary() -> tuple[dict[str, int], dict[str, dict[str, int]]]:
    """Deprecated: patient active/inactive concept removed. Kept for backward compatibility with zero counts."""
    global_counts: dict[str, int] = {"active": 0, "inactive": 0}
    per_doctor: defaultdict[str, dict[str, int]] = defaultdict(lambda: {"active": 0, "inactive": 0})
    return global_counts, per_doctor
