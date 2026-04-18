from datetime import datetime, timezone, timedelta, date
from typing import List, Optional

from beanie import PydanticObjectId as OID
from beanie.operators import Or
from fastapi import HTTPException

from app.models import ImplantStage, Appointment, Patient, User, DoctorWorkingHours
from app.services import patient_service

# المراحل الثابتة لزراعة الأسنان
IMPLANT_STAGES = [
    "مرحلة زراعة الاسنان",
    "مرحلة رفع خيط العملية",
    "متابعة حالة المريض",
    "المتابعة الثانية لحالة المريض",
    "التقاط طبعة الاسنان",
    "التركيب التجريبي الاول",
    "التركيب التجريبي الثاني",
    "التركيب النهائي الاخير",
]


async def _get_doctor_start_time(doctor_id: str, target_date: date) -> str:
    """جلب أول وقت عمل للطبيب في يوم معين."""
    # حساب day_of_week (0=Sunday, 1=Monday, ..., 6=Saturday)
    day_of_week = target_date.weekday()  # 0=Monday, 6=Sunday
    day_of_week = (day_of_week + 1) % 7  # Convert to Sunday=0 format

    # جلب أوقات عمل الطبيب لهذا اليوم
    working_hours = await DoctorWorkingHours.find_one(
        DoctorWorkingHours.doctor_id == OID(doctor_id),
        DoctorWorkingHours.day_of_week == day_of_week,
        DoctorWorkingHours.is_working == True,
    )

    if working_hours:
        return working_hours.start_time

    # إذا لم يكن الطبيب يعمل في هذا اليوم، نستخدم 9 صباحاً كافتراضي
    return "09:00"


async def initialize_implant_stages(
    patient_id: str,
    registration_date: datetime,
    doctor_id: str,
) -> List[ImplantStage]:
    """تهيئة مراحل زراعة الأسنان للمريض - إنشاء سلسلة مراحل خاصة بطبيب معيّن.

    - لكل (مريض، طبيب) سلسلة مستقلة من المراحل.
    - السجلات القديمة التي لا تحتوي على doctor_id يمكن ترقيتها لتُنسب لهذا الطبيب.
    """

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    did = OID(doctor_id)

    # 1) هل توجد بالفعل مراحل لهذا المريض وهذا الطبيب؟
    existing_stages = await ImplantStage.find(
        ImplantStage.patient_id == patient.id,
        ImplantStage.doctor_id == did,
    ).sort("+scheduled_at").to_list()
    if existing_stages:
        return existing_stages

    # 2) دعم البيانات القديمة: إن وُجدت مراحل بدون doctor_id، ننسبها لهذا الطبيب لمرة واحدة
    legacy_stages = await ImplantStage.find(
        ImplantStage.patient_id == patient.id,
        ImplantStage.doctor_id == None,  # type: ignore[comparison-overlap]
    ).sort("+scheduled_at").to_list()
    if legacy_stages:
        for s in legacy_stages:
            s.doctor_id = did
            await s.save()
        return legacy_stages

    # 3) لا توجد مراحل للمريض مع هذا الطبيب -> إنشاء السلسلة الجديدة (نبدأ بالمرحلة الأولى فقط)
    # استخدام تاريخ اليوم المحلي بدلاً من تاريخ التسجيل
    local_today = date.today()  # تاريخ اليوم المحلي

    # جلب أول وقت عمل للطبيب في هذا اليوم
    start_time_str = await _get_doctor_start_time(doctor_id, local_today)
    start_hour, start_minute = map(int, start_time_str.split(":"))

    # إنشاء datetime من تاريخ اليوم مع أول وقت عمل للطبيب كتوقيت "محلي" بدون تحويلات زمنية
    # ملاحظة: بقية النظام (المواعيد العادية) يخزن الأوقات كتوقيت محلي بدون timezone،
    # لذلك نتبع نفس النمط هنا لتجنب فروقات ٣ ساعات بين أنواع المواعيد.
    base_date = datetime.combine(
        local_today,
        datetime.min.time().replace(hour=start_hour, minute=start_minute),
    )
    first_stage_name = IMPLANT_STAGES[0]

    # إنشاء Appointment للمرحلة الأولى
    now = datetime.now(timezone.utc)
    appointment = Appointment(
        patient_id=patient.id,
        doctor_id=did,
        scheduled_at=base_date,
        note=f"موعد {first_stage_name}",
        status="pending",  # الحالة الافتراضية: قيد الانتظار
        stage_name=first_stage_name,
        created_at=now,
        updated_at=now,
    )
    await appointment.insert()

    # إنشاء ImplantStage للمرحلة الأولى فقط (مرتبطة بالطبيب الحالي)
    stage = ImplantStage(
        patient_id=patient.id,
        doctor_id=did,
        stage_name=first_stage_name,
        scheduled_at=base_date,
        is_completed=False,
        appointment_id=appointment.id,
    )
    await stage.insert()

    return [stage]


async def get_implant_stages(
    patient_id: str,
    doctor_id: Optional[str] = None,
) -> List[ImplantStage]:
    """جلب مراحل زراعة الأسنان للمريض.

    - في حالة الطبيب: نعيد فقط المراحل المرتبطة بهذا الطبيب.
      مع ترقية السجلات القديمة (بدون doctor_id) لتُنسب للطبيب الذي يستخدمها أولاً.
    - في حالة المريض أو الاستقبال: نعيد جميع المراحل للمريض بغض النظر عن الطبيب.
    """

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    if doctor_id is not None:
        did = OID(doctor_id)

        # 1) جرّب جلب مراحل هذا الطبيب مباشرة
        stages = (
            await ImplantStage.find(
                ImplantStage.patient_id == patient.id,
                ImplantStage.doctor_id == did,
            )
            .sort("+scheduled_at")
            .to_list()
        )
        if stages:
            return stages

        # 2) لا توجد مراحل مربوطة بهذا الطبيب، ابحث عن مراحل قديمة بدون doctor_id
        legacy_stages = (
            await ImplantStage.find(
                ImplantStage.patient_id == patient.id,
                ImplantStage.doctor_id == None,  # type: ignore[comparison-overlap]
            )
            .sort("+scheduled_at")
            .to_list()
        )
        if not legacy_stages:
            return []

        # 3) ترقيتها للطبيب الحالي حتى لا يراها أي طبيب آخر مستقبلاً
        for s in legacy_stages:
            s.doctor_id = did
            await s.save()

        return legacy_stages

    # للمريض أو الاستقبال: جميع المراحل للمريض
    stages = (
        await ImplantStage.find(ImplantStage.patient_id == patient.id)
        .sort("+scheduled_at")
        .to_list()
    )

    return stages


async def update_stage_date(
    patient_id: str,
    stage_name: str,
    new_date: datetime,
    doctor_id: str,
) -> ImplantStage:
    """تحديث تاريخ مرحلة زراعة (للطبيب فقط)."""

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    did = OID(doctor_id)
    if did not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")

    # البحث عن المرحلة الخاصة بهذا الطبيب (مع دعم مؤقت للسجلات القديمة)
    stage = await ImplantStage.find_one(
        ImplantStage.patient_id == patient.id,
        ImplantStage.stage_name == stage_name,
        Or(ImplantStage.doctor_id == did, ImplantStage.doctor_id == None),  # دعم السجلات القديمة
    )

    if not stage:
        raise HTTPException(status_code=404, detail="Stage not found")

    # في حال كانت مرحلة قديمة بدون doctor_id ننسبها للطبيب الحالي
    if stage.doctor_id is None:
        stage.doctor_id = did

    # نعمل دائماً بتوقيت "محلي" بدون timezone لتوحيد السلوك مع بقية المواعيد
    base_new_date = new_date
    if base_new_date.tzinfo is not None:
        base_new_date = base_new_date.replace(tzinfo=None)

    # تحديث تاريخ المرحلة الحالية
    stage.scheduled_at = base_new_date
    stage.updated_at = datetime.now(timezone.utc)
    await stage.save()

    # تحديث/إنشاء Appointment المرتبط بالمرحلة الحالية
    # ⚠️ مهم: عند تعديل موعد مريض الزراعة، يجب تحديث نفس الموعد وليس إنشاء موعد جديد
    if stage.appointment_id:
        appointment = await Appointment.get(stage.appointment_id)
        if appointment:
            # تحديث نفس الموعد (حفظ التاريخ القديم)
            appointment.previous_scheduled_at = appointment.scheduled_at
            appointment.scheduled_at = base_new_date
            appointment.updated_at = datetime.now(timezone.utc)
            # إذا كان الموعد مكتملاً، نعيده إلى pending عند التعديل
            if appointment.status == "completed":
                appointment.status = "pending"
            await appointment.save()
        else:
            # إذا لم يكن الموعد موجوداً فعلياً، ننشئ واحداً جديداً
            now = datetime.now(timezone.utc)
            appointment = Appointment(
                patient_id=patient.id,
                doctor_id=did,
                scheduled_at=base_new_date,
                note=f"موعد {stage_name}",
                status="pending",
                stage_name=stage_name,
                created_at=now,
                updated_at=now,
            )
            await appointment.insert()
            stage.appointment_id = appointment.id
            await stage.save()
    else:
        # إنشاء Appointment جديد إذا لم يكن موجوداً
        now = datetime.now(timezone.utc)
        appointment = Appointment(
            patient_id=patient.id,
            doctor_id=did,
            scheduled_at=base_new_date,
            note=f"موعد {stage_name}",
            status="pending",
            stage_name=stage_name,
            created_at=now,
            updated_at=now,
        )
        await appointment.insert()
        stage.appointment_id = appointment.id
        await stage.save()

    # بعد تعديل موعد هذه المرحلة، نعيد حساب مواعيد جميع المراحل التالية
    try:
        current_index = IMPLANT_STAGES.index(stage_name)
        previous_stage_name = stage_name
        previous_date = base_new_date

        for next_index in range(current_index + 1, len(IMPLANT_STAGES)):
            next_stage_name = IMPLANT_STAGES[next_index]

            # جلب المرحلة التالية (الخاصة بنفس الطبيب)
            next_stage = await ImplantStage.find_one(
                ImplantStage.patient_id == patient.id,
                ImplantStage.stage_name == next_stage_name,
                Or(
                    ImplantStage.doctor_id == did,
                    ImplantStage.doctor_id == None,  # دعم السجلات القديمة
                ),
            )
            if not next_stage:
                # إذا لم تكن المرحلة التالية موجودة، نتجاوز بدون إيقاف السلسلة
                previous_stage_name = next_stage_name
                continue

            if next_stage.doctor_id is None:
                next_stage.doctor_id = did

            # حساب التاريخ الجديد للمرحلة التالية اعتماداً على التاريخ الحالي
            next_date = await _get_next_stage_date(
                previous_stage_name,
                previous_date,
                doctor_id,
            )

            # نزيل أي timezone ونخزن كتوقيت محلي بسيط
            if next_date.tzinfo is not None:
                next_date = next_date.replace(tzinfo=None)

            next_stage.scheduled_at = next_date
            next_stage.updated_at = datetime.now(timezone.utc)
            await next_stage.save()

            # تحديث/إنشاء الموعد المرتبط بالمرحلة التالية
            # ⚠️ مهم: عند تعديل موعد مريض الزراعة، يجب تحديث نفس الموعد وليس إنشاء موعد جديد
            if next_stage.appointment_id:
                next_appt = await Appointment.get(next_stage.appointment_id)
                if next_appt:
                    # تحديث نفس الموعد (حفظ التاريخ القديم)
                    next_appt.previous_scheduled_at = next_appt.scheduled_at
                    next_appt.scheduled_at = next_date
                    next_appt.updated_at = datetime.now(timezone.utc)
                    # إذا كان الموعد مكتملاً، نعيده إلى pending عند التعديل
                    if next_appt.status == "completed":
                        next_appt.status = "pending"
                    await next_appt.save()
                else:
                    # إذا لم يكن الموعد موجوداً فعلياً، ننشئ واحداً جديداً
                    now = datetime.now(timezone.utc)
                    next_appt = Appointment(
                        patient_id=patient.id,
                        doctor_id=did,
                        scheduled_at=next_date,
                        note=f"موعد {next_stage_name}",
                        status="pending",
                        stage_name=next_stage_name,
                        created_at=now,
                        updated_at=now,
                    )
                    await next_appt.insert()
                    next_stage.appointment_id = next_appt.id
                    await next_stage.save()
            else:
                # إنشاء Appointment جديد إذا لم يكن موجوداً
                now = datetime.now(timezone.utc)
                next_appt = Appointment(
                    patient_id=patient.id,
                    doctor_id=did,
                    scheduled_at=next_date,
                    note=f"موعد {next_stage_name}",
                    status="pending",
                    stage_name=next_stage_name,
                    created_at=now,
                    updated_at=now,
                )
                await next_appt.insert()
                next_stage.appointment_id = next_appt.id
                await next_stage.save()

            # تصبح هذه المرحلة هي "السابقة" للمرحلة التي بعدها
            previous_stage_name = next_stage_name
            previous_date = next_date
    except ValueError:
        # إذا لم تكن المرحلة الحالية ضمن القائمة الثابتة، لا نعيد حساب السلسلة
        pass

    return stage


async def _get_next_stage_date(
    current_stage_name: str,
    current_stage_date: datetime,
    doctor_id: str,
) -> datetime:
    """حساب تاريخ المرحلة التالية بناءً على المرحلة الحالية."""

    try:
        current_index = IMPLANT_STAGES.index(current_stage_name)
        if current_index >= len(IMPLANT_STAGES) - 1:
            # لا توجد مرحلة تالية
            return current_stage_date

        next_stage_name = IMPLANT_STAGES[current_index + 1]

        # حساب التاريخ بناءً على نوع المرحلة
        if current_index == 0:
            # بعد مرحلة الزراعة: رفع الخيط بعد أسبوع
            days_to_add = 7
        else:
            # باقي المراحل: كل 30 يوم بعد المرحلة السابقة
            days_to_add = 30

        # نعمل دائماً بتوقيت "محلي" بدون timezone لتوحيد السلوك مع المواعيد العادية
        base_date = current_stage_date
        # إذا جاء التاريخ من قاعدة البيانات مع timezone، نتجاهل الـ tz ونأخذ التاريخ/الوقت كما هو
        if base_date.tzinfo is not None:
            base_date = base_date.replace(tzinfo=None)

        next_date_local = (base_date.date() + timedelta(days=days_to_add))

        # جلب أول وقت عمل للطبيب في يوم التاريخ التالي
        start_time_str = await _get_doctor_start_time(doctor_id, next_date_local)
        start_hour, start_minute = map(int, start_time_str.split(":"))

        # إنشاء datetime مع أول وقت عمل للطبيب (محلي بدون timezone)
        next_date = datetime.combine(
            next_date_local,
            datetime.min.time().replace(hour=start_hour, minute=start_minute),
        )

        return next_date
    except ValueError:
        # إذا لم تكن المرحلة في القائمة، نضيف 30 يوماً بنفس منطق التوقيت المحلي
        base_date = current_stage_date
        if base_date.tzinfo is not None:
            base_date = base_date.replace(tzinfo=None)

        next_date_local = (base_date.date() + timedelta(days=30))
        # جلب أول وقت عمل للطبيب
        start_time_str = await _get_doctor_start_time(doctor_id, next_date_local)
        start_hour, start_minute = map(int, start_time_str.split(":"))
        next_date = datetime.combine(
            next_date_local,
            datetime.min.time().replace(hour=start_hour, minute=start_minute),
        )
        return next_date


async def complete_stage(
    patient_id: str,
    stage_name: str,
    doctor_id: str,
) -> ImplantStage:
    """إكمال مرحلة زراعة (للطبيب فقط) - مع التحقق من التسلسل وإنشاء المرحلة التالية."""

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    did = OID(doctor_id)
    if did not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")

    # البحث عن المرحلة الخاصة بهذا الطبيب (مع دعم مؤقت للسجلات القديمة)
    stage = await ImplantStage.find_one(
        ImplantStage.patient_id == patient.id,
        ImplantStage.stage_name == stage_name,
        Or(ImplantStage.doctor_id == did, ImplantStage.doctor_id == None),  # دعم السجلات القديمة
    )

    if not stage:
        raise HTTPException(status_code=404, detail="Stage not found")

    if stage.doctor_id is None:
        stage.doctor_id = did

    # التحقق من التسلسل: يجب أن تكون المرحلة السابقة مكتملة (لنفس الطبيب)
    try:
        current_index = IMPLANT_STAGES.index(stage_name)
        if current_index > 0:
            # هناك مرحلة سابقة
            previous_stage_name = IMPLANT_STAGES[current_index - 1]
            previous_stage = await ImplantStage.find_one(
                ImplantStage.patient_id == patient.id,
                ImplantStage.stage_name == previous_stage_name,
                Or(
                    ImplantStage.doctor_id == did,
                    ImplantStage.doctor_id == None,  # دعم السجلات القديمة
                ),
            )

            if not previous_stage or not previous_stage.is_completed:
                raise HTTPException(
                    status_code=400,
                    detail=f"يجب إكمال المرحلة السابقة '{previous_stage_name}' أولاً",
                )
    except ValueError:
        # إذا لم تكن المرحلة في القائمة، نتابع بدون تحقق
        pass

    # تحديث حالة الإكمال
    stage.is_completed = True
    stage.updated_at = datetime.now(timezone.utc)
    await stage.save()

    # تحديث حالة Appointment المرتبط إلى "completed" (يختفي من الجداول)
    if stage.appointment_id:
        appointment = await Appointment.get(stage.appointment_id)
        if appointment:
            appointment.status = "completed"
            appointment.updated_at = datetime.now(timezone.utc)
            await appointment.save()

    # إنشاء / تحديث المرحلة التالية تلقائياً بناءً على موعد هذه المرحلة
    try:
        current_index = IMPLANT_STAGES.index(stage_name)
        if current_index < len(IMPLANT_STAGES) - 1:
            # هناك مرحلة تالية
            next_stage_name = IMPLANT_STAGES[current_index + 1]

            # حساب تاريخ المرحلة التالية بناءً على موعد هذه المرحلة (بعد 7 أيام أو 30 يوماً)
            next_date = await _get_next_stage_date(
                stage_name,
                stage.scheduled_at,
                doctor_id,
            )
            # نتأكد أن التاريخ مخزون كتوقيت محلي بدون timezone
            if next_date.tzinfo is not None:
                next_date = next_date.replace(tzinfo=None)

            # جلب المرحلة التالية (إن كانت موجودة لنفس الطبيب)
            existing_next_stage = await ImplantStage.find_one(
                ImplantStage.patient_id == patient.id,
                ImplantStage.stage_name == next_stage_name,
                Or(
                    ImplantStage.doctor_id == did,
                    ImplantStage.doctor_id == None,  # دعم السجلات القديمة
                ),
            )

            if not existing_next_stage:
                # إنشاء Appointment جديد للمرحلة التالية
                now = datetime.now(timezone.utc)
                next_appointment = Appointment(
                    patient_id=patient.id,
                    doctor_id=did,
                    scheduled_at=next_date,
                    note=f"موعد {next_stage_name}",
                    status="pending",  # الحالة الافتراضية: قيد الانتظار
                    stage_name=next_stage_name,
                    created_at=now,
                    updated_at=now,
                )
                await next_appointment.insert()

                # إنشاء ImplantStage جديد للمرحلة التالية
                next_stage = ImplantStage(
                    patient_id=patient.id,
                    doctor_id=did,
                    stage_name=next_stage_name,
                    scheduled_at=next_date,
                    is_completed=False,
                    appointment_id=next_appointment.id,
                )
                await next_stage.insert()
            else:
                if existing_next_stage.doctor_id is None:
                    existing_next_stage.doctor_id = did

                # تحديث موعد المرحلة التالية الموجودة أصلاً لتتوافق مع الموعد الجديد
                existing_next_stage.scheduled_at = next_date
                existing_next_stage.updated_at = datetime.now(timezone.utc)
                await existing_next_stage.save()

                if existing_next_stage.appointment_id:
                    next_appt = await Appointment.get(
                        existing_next_stage.appointment_id
                    )
                    if next_appt:
                        # تحديث نفس الموعد (حفظ التاريخ القديم)
                        next_appt.previous_scheduled_at = next_appt.scheduled_at
                        next_appt.scheduled_at = next_date
                        next_appt.updated_at = datetime.now(timezone.utc)
                        # إذا كان الموعد مكتملاً، نعيده إلى pending عند إعادة الحساب
                        if next_appt.status == "completed":
                            next_appt.status = "pending"
                        await next_appt.save()
                    else:
                        # إذا لم يكن هناك موعد مرتبط فعلياً، ننشئ واحداً جديداً
                        now = datetime.now(timezone.utc)
                        next_appt = Appointment(
                            patient_id=patient.id,
                            doctor_id=did,
                            scheduled_at=next_date,
                            note=f"موعد {next_stage_name}",
                            status="pending",
                            stage_name=next_stage_name,
                            created_at=now,
                            updated_at=now,
                        )
                        await next_appt.insert()
                        existing_next_stage.appointment_id = next_appt.id
                        await existing_next_stage.save()
                else:
                    # لا يوجد موعد مرتبط، ننشئ واحداً جديداً
                    now = datetime.now(timezone.utc)
                    next_appt = Appointment(
                        patient_id=patient.id,
                        doctor_id=did,
                        scheduled_at=next_date,
                        note=f"موعد {next_stage_name}",
                        status="pending",
                        stage_name=next_stage_name,
                        created_at=now,
                        updated_at=now,
                    )
                    await next_appt.insert()
                    existing_next_stage.appointment_id = next_appt.id
                    await existing_next_stage.save()
    except ValueError:
        # إذا لم تكن المرحلة في القائمة، لا ننشئ مرحلة تالية
        pass

    return stage


async def uncomplete_stage(
    patient_id: str,
    stage_name: str,
    doctor_id: str,
) -> ImplantStage:
    """
    إلغاء إكمال مرحلة زراعة (للطبيب فقط).
    - إعادة حالة الموعد إلى "pending" (قيد الانتظار)
    - إعادة حساب الموعد التلقائي للمرحلة التالية حسب النظام الحالي
    """

    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    did = OID(doctor_id)
    if did not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")

    # البحث عن المرحلة الخاصة بهذا الطبيب
    stage = await ImplantStage.find_one(
        ImplantStage.patient_id == patient.id,
        ImplantStage.stage_name == stage_name,
        Or(ImplantStage.doctor_id == did, ImplantStage.doctor_id == None),  # دعم السجلات القديمة
    )

    if not stage:
        raise HTTPException(status_code=404, detail="Stage not found")

    if stage.doctor_id is None:
        stage.doctor_id = did

    # تحديث حالة الإكمال
    stage.is_completed = False
    stage.updated_at = datetime.now(timezone.utc)
    await stage.save()

    # تحديث حالة Appointment المرتبط إلى "pending" (قيد الانتظار)
    if stage.appointment_id:
        appointment = await Appointment.get(stage.appointment_id)
        if appointment:
            appointment.status = "pending"
            appointment.updated_at = datetime.now(timezone.utc)
            await appointment.save()

    # إعادة حساب الموعد التلقائي للمرحلة التالية حسب النظام الحالي
    try:
        current_index = IMPLANT_STAGES.index(stage_name)
        if current_index < len(IMPLANT_STAGES) - 1:
            # هناك مرحلة تالية
            next_stage_name = IMPLANT_STAGES[current_index + 1]

            # حساب تاريخ المرحلة التالية بناءً على موعد هذه المرحلة
            next_date = await _get_next_stage_date(
                stage_name,
                stage.scheduled_at,
                doctor_id,
            )
            # نتأكد أن التاريخ مخزون كتوقيت محلي بدون timezone
            if next_date.tzinfo is not None:
                next_date = next_date.replace(tzinfo=None)

            # جلب المرحلة التالية (إن كانت موجودة لنفس الطبيب)
            existing_next_stage = await ImplantStage.find_one(
                ImplantStage.patient_id == patient.id,
                ImplantStage.stage_name == next_stage_name,
                Or(
                    ImplantStage.doctor_id == did,
                    ImplantStage.doctor_id == None,  # دعم السجلات القديمة
                ),
            )

            if existing_next_stage:
                if existing_next_stage.doctor_id is None:
                    existing_next_stage.doctor_id = did

                # تحديث موعد المرحلة التالية
                existing_next_stage.scheduled_at = next_date
                existing_next_stage.updated_at = datetime.now(timezone.utc)
                await existing_next_stage.save()

                # تحديث/إنشاء الموعد المرتبط بالمرحلة التالية
                if existing_next_stage.appointment_id:
                    next_appt = await Appointment.get(
                        existing_next_stage.appointment_id
                    )
                    if next_appt:
                        # تحديث نفس الموعد (حفظ التاريخ القديم)
                        next_appt.previous_scheduled_at = next_appt.scheduled_at
                        next_appt.scheduled_at = next_date
                        next_appt.status = "pending"  # إعادة إلى قيد الانتظار
                        next_appt.updated_at = datetime.now(timezone.utc)
                        await next_appt.save()
                    else:
                        # إذا لم يكن هناك موعد مرتبط فعلياً، ننشئ واحداً جديداً
                        now = datetime.now(timezone.utc)
                        next_appt = Appointment(
                            patient_id=patient.id,
                            doctor_id=did,
                            scheduled_at=next_date,
                            note=f"موعد {next_stage_name}",
                            status="pending",
                            stage_name=next_stage_name,
                            created_at=now,
                            updated_at=now,
                        )
                        await next_appt.insert()
                        existing_next_stage.appointment_id = next_appt.id
                        await existing_next_stage.save()
                else:
                    # لا يوجد موعد مرتبط، ننشئ واحداً جديداً
                    now = datetime.now(timezone.utc)
                    next_appt = Appointment(
                        patient_id=patient.id,
                        doctor_id=did,
                        scheduled_at=next_date,
                        note=f"موعد {next_stage_name}",
                        status="pending",
                        stage_name=next_stage_name,
                        created_at=now,
                        updated_at=now,
                    )
                    await next_appt.insert()
                    existing_next_stage.appointment_id = next_appt.id
                    await existing_next_stage.save()
    except ValueError:
        # إذا لم تكن المرحلة في القائمة، لا نعيد حساب المرحلة التالية
        pass

    return stage

