from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, List
from collections import defaultdict

from app.models import (
    User, Patient, Doctor, Appointment, TreatmentNote, GalleryImage,
    ChatRoom, ChatMessage, Notification, DeviceToken, AssignmentLog, OTPRequest,
    InactivePatientLog
)
from app.constants import Role
from app.utils.logger import get_logger

logger = get_logger("stats_service")


def parse_dates(date_from: Optional[str], date_to: Optional[str]) -> tuple[Optional[datetime], Optional[datetime]]:
    """تحويل سلاسل from/to إلى كائنات datetime إن وُجدت."""
    df = datetime.fromisoformat(date_from.replace('Z', '+00:00')) if date_from else None
    dt = datetime.fromisoformat(date_to.replace('Z', '+00:00')) if date_to else None
    return df, dt


def format_date_group(date: datetime, group: str) -> str:
    """تنسيق التاريخ حسب نوع التجميع."""
    if group == "day":
        return date.strftime("%Y-%m-%d")
    elif group == "month":
        return date.strftime("%Y-%m")
    elif group == "year":
        return date.strftime("%Y")
    else:
        return date.strftime("%Y-%m-%d")


async def get_overview_stats(
    group: str = "day",
    date_from: Optional[str] = None,
    date_to: Optional[str] = None
) -> Dict:
    """ملخص عام شامل: مرضى جدد، مواعيد، سجلات، صور، محادثات، إشعارات."""
    df, dt = parse_dates(date_from, date_to)
    
    # بناء queries
    user_query = User.find(User.role == Role.PATIENT)
    appointment_query = Appointment.find()
    note_query = TreatmentNote.find()
    image_query = GalleryImage.find()
    chat_room_query = ChatRoom.find()
    chat_message_query = ChatMessage.find()
    notification_query = Notification.find()
    
    if df:
        user_query = user_query.find(User.created_at >= df)
        appointment_query = appointment_query.find(Appointment.scheduled_at >= df)
        note_query = note_query.find(TreatmentNote.created_at >= df)
        image_query = image_query.find(GalleryImage.created_at >= df)
        chat_room_query = chat_room_query.find()  # ChatRoom doesn't have created_at
        chat_message_query = chat_message_query.find(ChatMessage.created_at >= df)
        notification_query = notification_query.find(Notification.sent_at >= df)
    
    if dt:
        user_query = user_query.find(User.created_at < dt)
        appointment_query = appointment_query.find(Appointment.scheduled_at < dt)
        note_query = note_query.find(TreatmentNote.created_at < dt)
        image_query = image_query.find(GalleryImage.created_at < dt)
        chat_message_query = chat_message_query.find(ChatMessage.created_at < dt)
        notification_query = notification_query.find(Notification.sent_at < dt)
    
    # جلب البيانات
    users = await user_query.to_list()
    appointments = await appointment_query.to_list()
    notes = await note_query.to_list()
    images = await image_query.to_list()
    chat_messages = await chat_message_query.to_list()
    notifications = await notification_query.to_list()
    
    # تجميع البيانات
    new_patients = defaultdict(int)
    appointments_grouped = defaultdict(int)
    notes_grouped = defaultdict(int)
    images_grouped = defaultdict(int)
    messages_grouped = defaultdict(int)
    notifications_grouped = defaultdict(int)
    
    for user in users:
        period = format_date_group(user.created_at, group)
        new_patients[period] += 1
    
    for app in appointments:
        period = format_date_group(app.scheduled_at, group)
        appointments_grouped[period] += 1
    
    for note in notes:
        period = format_date_group(note.created_at, group)
        notes_grouped[period] += 1
    
    for img in images:
        period = format_date_group(img.created_at, group)
        images_grouped[period] += 1
    
    for msg in chat_messages:
        period = format_date_group(msg.created_at, group)
        messages_grouped[period] += 1
    
    for notif in notifications:
        period = format_date_group(notif.sent_at, group)
        notifications_grouped[period] += 1
    
    return {
        "group": group,
        "range": {"from": date_from, "to": date_to},
        "new_patients": [{"period": k, "count": v} for k, v in sorted(new_patients.items())],
        "appointments": [{"period": k, "count": v} for k, v in sorted(appointments_grouped.items())],
        "notes": [{"period": k, "count": v} for k, v in sorted(notes_grouped.items())],
        "images": [{"period": k, "count": v} for k, v in sorted(images_grouped.items())],
        "chat_messages": [{"period": k, "count": v} for k, v in sorted(messages_grouped.items())],
        "notifications": [{"period": k, "count": v} for k, v in sorted(notifications_grouped.items())],
    }


async def get_users_stats() -> Dict:
    """إحصائيات المستخدمين حسب الدور."""
    total_users = await User.count()
    patients = await User.find(User.role == Role.PATIENT).count()
    doctors = await User.find(User.role == Role.DOCTOR).count()
    receptionists = await User.find(User.role == Role.RECEPTIONIST).count()
    photographers = await User.find(User.role == Role.PHOTOGRAPHER).count()
    call_centers = await User.find(User.role == Role.CALL_CENTER).count()
    admins = await User.find(User.role == Role.ADMIN).count()
    
    return {
        "total_users": total_users,
        "by_role": {
            "patients": patients,
            "doctors": doctors,
            "receptionists": receptionists,
            "photographers": photographers,
            "call_centers": call_centers,
            "admins": admins,
        }
    }


async def get_appointments_stats(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None
) -> Dict:
    """إحصائيات المواعيد الشاملة."""
    df, dt = parse_dates(date_from, date_to)
    
    query = Appointment.find()
    if df:
        query = query.find(Appointment.scheduled_at >= df)
    if dt:
        query = query.find(Appointment.scheduled_at < dt)
    
    appointments = await query.to_list()
    
    total = len(appointments)
    by_status = defaultdict(int)
    by_doctor = defaultdict(int)
    
    now = datetime.now(timezone.utc)
    upcoming = 0
    past = 0
    
    for app in appointments:
        by_status[app.status] += 1
        by_doctor[str(app.doctor_id)] += 1
        
        if app.scheduled_at > now and app.status == "scheduled":
            upcoming += 1
        elif app.scheduled_at < now:
            past += 1
    
    return {
        "total": total,
        "by_status": dict(by_status),
        "by_doctor": dict(by_doctor),
        "upcoming": upcoming,
        "past": past,
        "range": {"from": date_from, "to": date_to},
    }


async def get_doctors_stats() -> Dict:
    """إحصائيات الأطباء ومرضاهم."""
    doctors = await Doctor.find().to_list()
    stats = []
    
    for doctor in doctors:
        user = await User.get(doctor.user_id)
        # Count patients where this doctor is in their doctor_ids list
        from beanie.operators import In
        patients = await Patient.find(In(Patient.doctor_ids, [doctor.id])).to_list()
        total_patients = len(patients)
        
        appointments = await Appointment.find(Appointment.doctor_id == doctor.id).count()
        completed = await Appointment.find(
            Appointment.doctor_id == doctor.id,
            Appointment.status == "completed"
        ).count()
        
        notes = await TreatmentNote.find(TreatmentNote.doctor_id == doctor.id).count()
        
        stats.append({
            "doctor_id": str(doctor.id),
            "user_id": str(doctor.user_id),
            "name": user.name if user else None,
            "phone": user.phone if user else None,
            "imageUrl": user.imageUrl if user else None,
            "primary_patients": total_patients,  # For backward compatibility
            "secondary_patients": 0,  # No longer used
            "total_patients": total_patients,
            "total_appointments": appointments,
            "completed_appointments": completed,
            "treatment_notes": notes,
        })
    
    return {"doctors": stats, "total_doctors": len(stats)}


async def get_doctor_profile_stats(
    *,
    doctor_id: str,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
) -> Dict:
    """إحصائيات بروفايل الطبيب للمدير: مرضى/تحويلات/مواعيد/رسائل اليوم + تحويلات ضمن فترة."""
    from beanie import PydanticObjectId as OID
    from beanie.operators import In

    try:
        did = OID(doctor_id)
    except Exception:
        return {"detail": "Invalid doctor_id"}

    doctor = await Doctor.get(did)
    if not doctor:
        return {"detail": "Doctor not found"}

    user = await User.get(doctor.user_id)

    # Patients assigned to this doctor
    total_patients = await Patient.find(In(Patient.doctor_ids, [did])).count()

    # Appointments
    total_appointments = await Appointment.find(Appointment.doctor_id == did).count()

    # Messages today (all messages in rooms belonging to this doctor)
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)
    primary_rooms = await ChatRoom.find(ChatRoom.doctor_user_id == doctor.user_id).to_list()
    legacy_rooms = await ChatRoom.find(
        ChatRoom.doctor_user_id == None,
        ChatRoom.doctor_id == did,
    ).to_list()
    room_ids: list[OID] = []
    seen_ids: set[str] = set()
    for room in primary_rooms + legacy_rooms:
        room_key = str(room.id)
        if room_key in seen_ids:
            continue
        seen_ids.add(room_key)
        room_ids.append(room.id)
    if room_ids:
        total_messages = await ChatMessage.find(
            In(ChatMessage.room_id, room_ids),
        ).count()
        today_messages = await ChatMessage.find(
            In(ChatMessage.room_id, room_ids),
            ChatMessage.created_at >= today_start,
            ChatMessage.created_at < tomorrow_start,
        ).count()
    else:
        total_messages = 0
        today_messages = 0

    # Transfers (AssignmentLogs)
    transfers_today = await AssignmentLog.find(
        AssignmentLog.doctor_id == did,
        AssignmentLog.assigned_at >= today_start,
        AssignmentLog.assigned_at < tomorrow_start,
    ).count()

    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    next_month_start = (
        month_start.replace(year=month_start.year + 1, month=1)
        if month_start.month == 12
        else month_start.replace(month=month_start.month + 1)
    )
    transfers_month = await AssignmentLog.find(
        AssignmentLog.doctor_id == did,
        AssignmentLog.assigned_at >= month_start,
    ).count()

    df, dt = parse_dates(date_from, date_to)
    transfers_range_query = AssignmentLog.find(AssignmentLog.doctor_id == did)
    if df:
        transfers_range_query = transfers_range_query.find(AssignmentLog.assigned_at >= df)
    if dt:
        transfers_range_query = transfers_range_query.find(AssignmentLog.assigned_at < dt)
    transfers_in_range = await transfers_range_query.count()

    # Appointments: daily/monthly/range based on scheduled_at
    appointments_today = await Appointment.find(
        Appointment.doctor_id == did,
        Appointment.scheduled_at >= today_start,
        Appointment.scheduled_at < tomorrow_start,
    ).count()

    appointments_month = await Appointment.find(
        Appointment.doctor_id == did,
        Appointment.scheduled_at >= month_start,
        Appointment.scheduled_at < next_month_start,
    ).count()

    appointments_range_query = Appointment.find(Appointment.doctor_id == did)
    if df:
        appointments_range_query = appointments_range_query.find(Appointment.scheduled_at >= df)
    if dt:
        appointments_range_query = appointments_range_query.find(Appointment.scheduled_at < dt)
    appointments_in_range = await appointments_range_query.count()

    # Messages: daily/monthly/range based on created_at
    if room_ids:
        messages_month = await ChatMessage.find(
            In(ChatMessage.room_id, room_ids),
            ChatMessage.created_at >= month_start,
            ChatMessage.created_at < next_month_start,
        ).count()

        messages_range_query = ChatMessage.find(In(ChatMessage.room_id, room_ids))
        if df:
            messages_range_query = messages_range_query.find(ChatMessage.created_at >= df)
        if dt:
            messages_range_query = messages_range_query.find(ChatMessage.created_at < dt)
        messages_in_range = await messages_range_query.count()
    else:
        messages_month = 0
        messages_in_range = 0

    return {
        "doctor": {
            "doctor_id": str(doctor.id),
            "user_id": str(doctor.user_id),
            "name": user.name if user else None,
            "phone": user.phone if user else None,
            "imageUrl": user.imageUrl if user else None,
            "is_manager": doctor.is_manager,
        },
        "counts": {
            "total_patients": total_patients,
            "total_appointments": total_appointments,
            "today_messages": today_messages,
        },
        "messages": {
            "total": total_messages,
            "today": today_messages,
            "this_month": messages_month,
            "range": {
                "from": date_from,
                "to": date_to,
                "count": messages_in_range,
            },
        },
        "appointments": {
            "today": appointments_today,
            "this_month": appointments_month,
            "range": {
                "from": date_from,
                "to": date_to,
                "count": appointments_in_range,
            },
        },
        "transfers": {
            "today": transfers_today,
            "this_month": transfers_month,
            "range": {
                "from": date_from,
                "to": date_to,
                "count": transfers_in_range,
            },
        },
    }


async def get_patient_activity_stats(
    *,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    doctor_id: Optional[str] = None,
) -> Dict:
    """Deprecated: patient active/inactive concept تمت إزالتها. نرجع أصفار فقط للتوافق."""
    return {
        "active": 0,
        "inactive": 0,
        "range": {"from": date_from, "to": date_to},
    }


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


async def get_doctor_patient_transfer_stats(
    *,
    doctor_id: str,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
) -> Dict:
    """
    إحصائيات المرضى المحولين لهذا الطبيب:
    - عدد المرضى المحولين خلال اليوم/الشهر/فترة محددة (من AssignmentLog)
    - عدد المرضى النشطين خلال اليوم/الشهر/فترة محددة (transfers - inactive)
    - عدد المرضى غير النشطين (حتى لو تم حذفهم من حسابه) خلال اليوم/الشهر/فترة محددة (من InactivePatientLog)
    
    ملاحظة: نستخدم AssignmentLog لحساب التحويلات و InactivePatientLog لحساب غير النشطين.
    """
    from beanie import PydanticObjectId as OID
    from beanie.operators import And
    
    try:
        did = OID(doctor_id)
    except Exception:
        return {"detail": "Invalid doctor_id"}
    
    doctor = await Doctor.get(did)
    if not doctor:
        return {"detail": "Doctor not found"}
    
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)
    
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if month_start.month == 12:
        next_month_start = month_start.replace(year=month_start.year + 1, month=1)
    else:
        next_month_start = month_start.replace(month=month_start.month + 1)
    
    df, dt = parse_dates(date_from, date_to)
    
    # حساب عدد التحويلات من AssignmentLog
    transfers_today = await AssignmentLog.find(
        AssignmentLog.doctor_id == did,
        AssignmentLog.assigned_at >= today_start,
        AssignmentLog.assigned_at < tomorrow_start,
    ).count()
    
    transfers_month = await AssignmentLog.find(
        AssignmentLog.doctor_id == did,
        AssignmentLog.assigned_at >= month_start,
        AssignmentLog.assigned_at < next_month_start,
    ).count()
    
    transfers_range_query = AssignmentLog.find(AssignmentLog.doctor_id == did)
    if df:
        transfers_range_query = transfers_range_query.find(AssignmentLog.assigned_at >= df)
    if dt:
        transfers_range_query = transfers_range_query.find(AssignmentLog.assigned_at < dt)
    transfers_in_range = await transfers_range_query.count()
    
    # حساب عدد غير النشطين من InactivePatientLog (حسب original_assigned_at)
    inactive_today = await InactivePatientLog.find(
        InactivePatientLog.doctor_id == did,
        InactivePatientLog.original_assigned_at >= today_start,
        InactivePatientLog.original_assigned_at < tomorrow_start,
    ).count()
    
    inactive_month = await InactivePatientLog.find(
        InactivePatientLog.doctor_id == did,
        InactivePatientLog.original_assigned_at >= month_start,
        InactivePatientLog.original_assigned_at < next_month_start,
    ).count()
    
    inactive_range_query = InactivePatientLog.find(InactivePatientLog.doctor_id == did)
    if df:
        inactive_range_query = inactive_range_query.find(InactivePatientLog.original_assigned_at >= df)
    if dt:
        inactive_range_query = inactive_range_query.find(InactivePatientLog.original_assigned_at < dt)
    inactive_in_range = await inactive_range_query.count()
    
    # حساب النشطين: التحويلات - غير النشطين
    active_today = max(0, transfers_today - inactive_today)
    active_month = max(0, transfers_month - inactive_month)
    active_in_range = max(0, transfers_in_range - inactive_in_range)
    
    return {
        "doctor_id": doctor_id,
        "transfers": {
            "today": transfers_today,
            "this_month": transfers_month,
            "range": {
                "from": date_from,
                "to": date_to,
                "count": transfers_in_range,
            },
        },
        "active_patients": {
            "today": active_today,
            "this_month": active_month,
            "range": {
                "from": date_from,
                "to": date_to,
                "count": active_in_range,
            },
        },
        "inactive_patients": {
            "today": inactive_today,
            "this_month": inactive_month,
            "range": {
                "from": date_from,
                "to": date_to,
                "count": inactive_in_range,
            },
        },
    }


async def get_all_doctors_patient_transfer_stats(
    *,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
) -> Dict:
    """
    إحصائيات المرضى المحولين لجميع الأطباء (للطبيب المدير):
    - عدد المرضى المحولين يومياً وشهرياً لكل طبيب
    - عدد المرضى النشطين يومياً وشهرياً لكل طبيب
    - عدد المرضى غير النشطين يومياً وشهرياً لكل طبيب
    
    ملاحظة: نستخدم AssignmentLog لحساب التحويلات و InactivePatientLog لحساب غير النشطين.
    """
    from beanie import PydanticObjectId as OID
    from beanie.operators import In
    
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)
    
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if month_start.month == 12:
        next_month_start = month_start.replace(year=month_start.year + 1, month=1)
    else:
        next_month_start = month_start.replace(month=month_start.month + 1)
    
    df, dt = parse_dates(date_from, date_to)
    
    # جلب جميع الأطباء
    doctors = await Doctor.find({}).to_list()
    user_ids = list({d.user_id for d in doctors if d.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}
    
    doctors_stats = []
    
    for doctor in doctors:
        user = user_map.get(doctor.user_id)
        if not user:
            continue
        
        did = doctor.id
        
        # حساب عدد التحويلات من AssignmentLog
        transfers_today = await AssignmentLog.find(
            AssignmentLog.doctor_id == did,
            AssignmentLog.assigned_at >= today_start,
            AssignmentLog.assigned_at < tomorrow_start,
        ).count()
        
        transfers_month = await AssignmentLog.find(
            AssignmentLog.doctor_id == did,
            AssignmentLog.assigned_at >= month_start,
            AssignmentLog.assigned_at < next_month_start,
        ).count()
        
        transfers_range_query = AssignmentLog.find(AssignmentLog.doctor_id == did)
        if df:
            transfers_range_query = transfers_range_query.find(AssignmentLog.assigned_at >= df)
        if dt:
            transfers_range_query = transfers_range_query.find(AssignmentLog.assigned_at < dt)
        transfers_in_range = await transfers_range_query.count()
        
        # حساب عدد غير النشطين من InactivePatientLog (حسب original_assigned_at)
        inactive_today = await InactivePatientLog.find(
            InactivePatientLog.doctor_id == did,
            InactivePatientLog.original_assigned_at >= today_start,
            InactivePatientLog.original_assigned_at < tomorrow_start,
        ).count()
        
        inactive_month = await InactivePatientLog.find(
            InactivePatientLog.doctor_id == did,
            InactivePatientLog.original_assigned_at >= month_start,
            InactivePatientLog.original_assigned_at < next_month_start,
        ).count()
        
        inactive_range_query = InactivePatientLog.find(InactivePatientLog.doctor_id == did)
        if df:
            inactive_range_query = inactive_range_query.find(InactivePatientLog.original_assigned_at >= df)
        if dt:
            inactive_range_query = inactive_range_query.find(InactivePatientLog.original_assigned_at < dt)
        inactive_in_range = await inactive_range_query.count()
        
        # حساب النشطين: التحويلات - غير النشطين
        active_today = max(0, transfers_today - inactive_today)
        active_month = max(0, transfers_month - inactive_month)
        active_in_range = max(0, transfers_in_range - inactive_in_range)
        
        doctors_stats.append({
            "doctor_id": str(doctor.id),
            "user_id": str(doctor.user_id),
            "name": user.name,
            "phone": user.phone,
            "imageUrl": user.imageUrl,
            "transfers": {
                "today": transfers_today,
                "this_month": transfers_month,
                "range": {
                    "from": date_from,
                    "to": date_to,
                    "count": transfers_in_range,
                },
            },
            "active_patients": {
                "today": active_today,
                "this_month": active_month,
                "range": {
                    "from": date_from,
                    "to": date_to,
                    "count": active_in_range,
                },
            },
            "inactive_patients": {
                "today": inactive_today,
                "this_month": inactive_month,
                "range": {
                    "from": date_from,
                    "to": date_to,
                    "count": inactive_in_range,
                },
            },
        })
    
    return {
        "doctors": doctors_stats,
        "total_doctors": len(doctors_stats),
        "range": {
            "from": date_from,
            "to": date_to,
        },
    }


async def get_chat_stats(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None
) -> Dict:
    """إحصائيات المحادثات."""
    df, dt = parse_dates(date_from, date_to)
    
    rooms_query = ChatRoom.find()
    messages_query = ChatMessage.find()
    
    if df:
        messages_query = messages_query.find(ChatMessage.created_at >= df)
    if dt:
        messages_query = messages_query.find(ChatMessage.created_at < dt)
    
    total_rooms = await rooms_query.count()
    total_messages = await messages_query.count()
    
    # إحصائيات حسب الطبيب
    rooms = await rooms_query.to_list()
    messages = await messages_query.to_list()
    
    messages_by_doctor = defaultdict(int)
    rooms_by_doctor = defaultdict(int)
    
    for room in rooms:
        rooms_by_doctor[str(room.doctor_id)] += 1
    
    for msg in messages:
        # نحتاج معرف الطبيب من الغرفة
        room = await ChatRoom.get(msg.room_id)
        if room:
            messages_by_doctor[str(room.doctor_id)] += 1
    
    return {
        "total_rooms": total_rooms,
        "total_messages": total_messages,
        "messages_by_doctor": dict(messages_by_doctor),
        "rooms_by_doctor": dict(rooms_by_doctor),
        "range": {"from": date_from, "to": date_to},
    }


async def get_notifications_stats(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None
) -> Dict:
    """إحصائيات الإشعارات."""
    df, dt = parse_dates(date_from, date_to)
    
    query = Notification.find()
    if df:
        query = query.find(Notification.sent_at >= df)
    if dt:
        query = query.find(Notification.sent_at < dt)
    
    total = await query.count()
    
    # عدد الأجهزة المسجلة
    total_devices = await DeviceToken.find(DeviceToken.active == True).count()
    
    return {
        "total_notifications": total,
        "total_active_devices": total_devices,
        "range": {"from": date_from, "to": date_to},
    }


async def get_transfers_stats(
    group: str = "day",
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    doctor_id: Optional[str] = None,
) -> Dict:
    """إحصائيات تحويلات المرضى بين الأطباء."""
    df, dt = parse_dates(date_from, date_to)
    
    query = AssignmentLog.find()
    if df:
        query = query.find(AssignmentLog.assigned_at >= df)
    if dt:
        query = query.find(AssignmentLog.assigned_at < dt)
    if doctor_id:
        # AssignmentLog.doctor_id هو ObjectId؛ نطابقه كنص عبر str() في التجميع لاحقاً.
        # هنا نحاول التحويل إلى ObjectId بأمان إن أمكن.
        try:
            from beanie import PydanticObjectId as OID
            query = query.find(AssignmentLog.doctor_id == OID(doctor_id))
        except Exception:
            # fallback: إن لم يكن معرف صالح، نخلي النتائج فاضية
            return {
                "group": group,
                "range": {"from": date_from, "to": date_to},
                "doctor_id": doctor_id,
                "by_period": [],
                "by_doctor": {},
                "total_transfers": 0,
            }
    
    logs = await query.to_list()
    
    by_period = defaultdict(int)
    by_doctor = defaultdict(int)
    
    for log in logs:
        period = format_date_group(log.assigned_at, group)
        by_period[period] += 1
        by_doctor[str(log.doctor_id)] += 1
    
    return {
        "group": group,
        "range": {"from": date_from, "to": date_to},
        "doctor_id": doctor_id,
        "by_period": [{"period": k, "count": v} for k, v in sorted(by_period.items())],
        "by_doctor": dict(by_doctor),
        "total_transfers": len(logs),
    }


async def get_dashboard_stats() -> Dict:
    """إحصائيات Dashboard شاملة - ملخص سريع."""
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    this_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    # إحصائيات عامة
    total_patients = await User.find(User.role == Role.PATIENT).count()
    total_doctors = await User.find(User.role == Role.DOCTOR).count()
    total_appointments = await Appointment.count()
    upcoming_appointments = await Appointment.find(
        Appointment.scheduled_at > now,
        Appointment.status == "scheduled"
    ).count()
    # إحصائيات اليوم
    today_patient_users = await User.find(
        User.role == Role.PATIENT,
        User.created_at >= today_start
    ).to_list()
    today_patients = len(today_patient_users)
    today_appointments = await Appointment.find(
        Appointment.scheduled_at >= today_start,
        Appointment.scheduled_at < today_start + timedelta(days=1)
    ).count()
    today_messages = await ChatMessage.find(
        ChatMessage.created_at >= today_start
    ).count()
    
    # إحصائيات هذا الشهر
    month_patient_users = await User.find(
        User.role == Role.PATIENT,
        User.created_at >= this_month_start
    ).to_list()
    month_patients = len(month_patient_users)
    month_appointments = await Appointment.find(
        Appointment.scheduled_at >= this_month_start
    ).count()
    
    # إحصائيات المواعيد حسب الحالة
    scheduled = await Appointment.find(Appointment.status == "scheduled").count()
    completed = await Appointment.find(Appointment.status == "completed").count()
    canceled = await Appointment.find(Appointment.status == "canceled").count()
    
    # إحصائيات المحادثات
    total_chat_rooms = await ChatRoom.count()
    total_chat_messages = await ChatMessage.count()
    
    # إحصائيات الإشعارات
    total_notifications = await Notification.count()
    active_devices = await DeviceToken.find(DeviceToken.active == True).count()

    # إحصائيات أنواع المرضى (جديد/قديم) ونوع المعاينة (مدفوعة/مجانية)
    # نعتمد على حقلي visit_type و consultation_type في وثيقة Patient.
    from beanie.operators import In as BeanieIn

    def _build_patient_type_summary(patients: list[Patient]) -> dict:
        visit_new = 0
        visit_old = 0
        visit_unknown = 0

        consult_paid = 0
        consult_free = 0
        consult_unknown = 0

        for p in patients:
            vt = getattr(p, "visit_type", None)
            if vt == "مريض جديد":
                visit_new += 1
            elif vt == "مراجع قديم":
                visit_old += 1
            else:
                visit_unknown += 1

            ct = getattr(p, "consultation_type", None)
            if ct == "معاينة مدفوعة":
                consult_paid += 1
            elif ct == "معاينة مجانية":
                consult_free += 1
            else:
                consult_unknown += 1

        return {
            "visit_type": {
                "new": visit_new,
                "old": visit_old,
                "unknown": visit_unknown,
            },
            "consultation_type": {
                "paid": consult_paid,
                "free": consult_free,
                "unknown": consult_unknown,
            },
        }

    # جميع المرضى
    all_patients = await Patient.find({}).to_list()

    # مرضى اليوم (حسب تاريخ إنشاء User)
    today_user_ids = [u.id for u in today_patient_users]
    patients_today: list[Patient] = []
    if today_user_ids:
        patients_today = await Patient.find(BeanieIn(Patient.user_id, today_user_ids)).to_list()

    # مرضى هذا الشهر (حسب تاريخ إنشاء User)
    month_user_ids = [u.id for u in month_patient_users]
    patients_month: list[Patient] = []
    if month_user_ids:
        patients_month = await Patient.find(BeanieIn(Patient.user_id, month_user_ids)).to_list()

    patient_type_summary = {
        "all": _build_patient_type_summary(all_patients),
        "today": _build_patient_type_summary(patients_today),
        "this_month": _build_patient_type_summary(patients_month),
    }
    
    return {
        "overview": {
            "total_patients": total_patients,
            "total_doctors": total_doctors,
            "total_appointments": total_appointments,
            "upcoming_appointments": upcoming_appointments,
        },
        "today": {
            "new_patients": today_patients,
            "appointments": today_appointments,
            "chat_messages": today_messages,
        },
        "this_month": {
            "new_patients": month_patients,
            "appointments": month_appointments,
        },
        "appointments_by_status": {
            "scheduled": scheduled,
            "completed": completed,
            "canceled": canceled,
        },
        "chat": {
            "total_rooms": total_chat_rooms,
            "total_messages": total_chat_messages,
        },
        "notifications": {
            "total_sent": total_notifications,
            "active_devices": active_devices,
        },
        "patient_types": patient_type_summary,
    }
