from typing import Optional, Any
from beanie import PydanticObjectId as OID

from app.models import DeviceToken, Notification, User
from app.constants import Role
from app.utils.firebase import send_firebase_message

# أنواع إشعارات المريض
NOTIFICATION_TYPES = {
    "appointment_created",
    "appointment_reminder",
    "appointment_updated",
    "message",
    "implant_stage",
    "general",
}


def _as_oid(value: str | OID | None) -> OID | None:
    if value is None:
        return None
    if isinstance(value, OID):
        return value
    s = str(value).strip()
    if not s:
        return None
    try:
        return OID(s)
    except Exception:
        return None


def _patient_scope_filter(patient_id: str | OID) -> dict[str, Any]:
    """
    إشعارات الفرد:
    - patient_id مطابق (حقل أو data.patientId للتوافق مع السجلات القديمة)
    - أو إشعار عام للحساب (type=general بدون patient)
    """
    pid = _as_oid(patient_id)
    pid_str = str(pid) if pid else str(patient_id)
    return {
        "$or": [
            {"patient_id": pid},
            {"data.patientId": pid_str},
            {
                "type": "general",
                "$and": [
                    {
                        "$or": [
                            {"patient_id": None},
                            {"patient_id": {"$exists": False}},
                        ]
                    },
                    {
                        "$or": [
                            {"data.patientId": {"$exists": False}},
                            {"data.patientId": None},
                            {"data.patientId": ""},
                        ]
                    },
                ],
            },
        ]
    }


async def register_device_token(*, user_id: str, token: str, platform: Optional[str]) -> DeviceToken:
    """Save or update an FCM device token for the user."""
    existing = await DeviceToken.find_one(DeviceToken.token == token)
    if existing:
        existing.user_id = OID(user_id)
        existing.platform = platform
        existing.active = True
        await existing.save()
        return existing
    dt = DeviceToken(user_id=OID(user_id), token=token, platform=platform)
    await dt.insert()
    return dt


async def notify_user(
    *,
    user_id: str | OID,
    title: str,
    body: str,
    type: str = "general",
    data: Optional[dict[str, Any]] = None,
    patient_id: str | OID | None = None,
) -> Notification:
    """Create an in-app notification and send push to all user devices."""
    uid = user_id if isinstance(user_id, OID) else OID(user_id)
    notif_type = type if type in NOTIFICATION_TYPES else "general"
    payload = dict(data or {})

    pid = _as_oid(patient_id)
    if pid is None:
        # توافق مع data.patientId إن وُجد
        pid = _as_oid(payload.get("patientId") or payload.get("patient_id"))
    if pid is not None:
        payload.setdefault("patientId", str(pid))

    notif = Notification(
        user_id=uid,
        patient_id=pid,
        title=title,
        body=body,
        type=notif_type,
        data=payload,
        is_read=False,
    )
    await notif.insert()

    tokens_docs = await DeviceToken.find(
        DeviceToken.user_id == uid,
        DeviceToken.active == True,  # noqa: E712
    ).to_list()
    tokens = [dt.token for dt in tokens_docs]
    if tokens:
        fcm_data = {
            "type": notif_type,
            "notification_id": str(notif.id),
            **{k: str(v) for k, v in payload.items() if v is not None},
        }
        await send_firebase_message(tokens, title, body, data=fcm_data)

    return notif


async def list_user_notifications(
    *,
    user_id: str | OID,
    skip: int = 0,
    limit: int = 50,
    unread_only: bool = False,
    patient_id: str | OID | None = None,
) -> list[Notification]:
    uid = user_id if isinstance(user_id, OID) else OID(user_id)
    filters: list[Any] = [Notification.user_id == uid]
    if unread_only:
        filters.append(Notification.is_read == False)  # noqa: E712
    if patient_id:
        filters.append(_patient_scope_filter(patient_id))

    query = Notification.find(*filters)
    return await query.sort(-Notification.sent_at).skip(skip).limit(limit).to_list()


async def unread_count(
    *,
    user_id: str | OID,
    patient_id: str | OID | None = None,
) -> int:
    uid = user_id if isinstance(user_id, OID) else OID(user_id)
    filters: list[Any] = [
        Notification.user_id == uid,
        Notification.is_read == False,  # noqa: E712
    ]
    if patient_id:
        filters.append(_patient_scope_filter(patient_id))
    return await Notification.find(*filters).count()


async def mark_as_read(*, user_id: str | OID, notification_id: str) -> Notification | None:
    uid = user_id if isinstance(user_id, OID) else OID(user_id)
    try:
        notif = await Notification.get(OID(notification_id))
    except Exception:
        return None
    if not notif or notif.user_id != uid:
        return None
    if not notif.is_read:
        notif.is_read = True
        await notif.save()
    return notif


async def mark_all_as_read(
    *,
    user_id: str | OID,
    patient_id: str | OID | None = None,
) -> int:
    uid = user_id if isinstance(user_id, OID) else OID(user_id)
    filters: list[Any] = [
        Notification.user_id == uid,
        Notification.is_read == False,  # noqa: E712
    ]
    if patient_id:
        filters.append(_patient_scope_filter(patient_id))
    unread = await Notification.find(*filters).to_list()
    for n in unread:
        n.is_read = True
        await n.save()
    return len(unread)


async def notify_all_patients(*, title: str, body: str, data: Optional[dict[str, Any]] = None) -> int:
    """Broadcast a general notification to all patient users."""
    patients = await User.find(User.role == Role.PATIENT).to_list()
    count = 0
    for user in patients:
        await notify_user(
            user_id=user.id,
            title=title,
            body=body,
            type="general",
            data=data,
            patient_id=None,
        )
        count += 1
    return count


async def notify_patient_new_message(
    *,
    patient_user_id: str | OID | None,
    doctor_user_id: str | OID | None,
    patient_id: str | None = None,
    room_id: str | None = None,
) -> None:
    """Notify patient when a doctor sends a chat message."""
    if not patient_user_id:
        return
    doctor_name = "طبيبك"
    try:
        if doctor_user_id:
            doctor_user = await User.get(
                doctor_user_id if isinstance(doctor_user_id, OID) else OID(str(doctor_user_id))
            )
            if doctor_user and doctor_user.name:
                doctor_name = doctor_user.name
    except Exception:
        pass

    await notify_user(
        user_id=patient_user_id,
        title="رسالة جديدة",
        body=f"رسالة جديدة من الدكتور {doctor_name}",
        type="message",
        patient_id=patient_id,
        data={
            k: v
            for k, v in {
                "patientId": patient_id,
                "roomId": room_id,
                "doctorUserId": str(doctor_user_id) if doctor_user_id else None,
            }.items()
            if v is not None
        },
    )


async def notify_patient_implant_stage(
    *,
    patient_user_id: str | OID | None,
    stage_name: str,
    scheduled_at=None,
    patient_id: str | None = None,
    stage_id: str | None = None,
) -> None:
    """Notify patient about an implant stage schedule update."""
    if not patient_user_id:
        return
    when = ""
    try:
        if scheduled_at is not None:
            when = scheduled_at.strftime("%d-%m-%Y")
    except Exception:
        when = ""

    if when:
        body = f"حان موعد المرحلة التالية: {stage_name} بتاريخ {when}"
    else:
        body = f"حان موعد المرحلة التالية: {stage_name}"

    await notify_user(
        user_id=patient_user_id,
        title="مرحلة زراعة أسنان",
        body=body,
        type="implant_stage",
        patient_id=patient_id,
        data={
            "patientId": patient_id,
            "stageId": stage_id,
            "stageName": stage_name,
        },
    )
