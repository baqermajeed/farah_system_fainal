from fastapi import APIRouter, Depends, HTTPException, Query
from datetime import timezone

from app.schemas import (
    DeviceTokenIn,
    NotificationOut,
    UnreadCountOut,
    GeneralNotificationIn,
    BroadcastResultOut,
)
from app.security import get_current_user, require_roles
from app.constants import Role
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _sent_at_iso(value) -> str:
    """Always emit UTC with timezone so clients don't treat it as local time."""
    if value is None:
        return ""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    else:
        value = value.astimezone(timezone.utc)
    return value.isoformat().replace("+00:00", "Z")


def _to_out(n) -> NotificationOut:
    data = getattr(n, "data", None) or {}
    # أظهر patientId دائماً في data لتسهيل التصفية على العميل
    if getattr(n, "patient_id", None) is not None:
        data = {**data, "patientId": str(n.patient_id)}
    return NotificationOut(
        id=str(n.id),
        title=n.title,
        body=n.body,
        type=getattr(n, "type", None) or "general",
        data=data,
        is_read=bool(getattr(n, "is_read", False)),
        sent_at=_sent_at_iso(getattr(n, "sent_at", None)),
    )


async def _resolve_patient_scope(current, patient_id: str | None) -> str | None:
    """للمرضى: نلزم تصفية بفرد العائلة. لغيرهم: اختياري."""
    if current.role != Role.PATIENT:
        return patient_id

    if not patient_id:
        raise HTTPException(
            status_code=400,
            detail="patient_id مطلوب لعرض إشعارات فرد العائلة",
        )
    try:
        await notification_service.ensure_patient_belongs_to_user(
            user_id=current.id,
            patient_id=patient_id,
        )
    except PermissionError:
        raise HTTPException(status_code=403, detail="Forbidden")
    except ValueError:
        raise HTTPException(status_code=400, detail="patient_id غير صالح")
    return patient_id


@router.post("/register", status_code=204)
async def register_token(payload: DeviceTokenIn, current=Depends(get_current_user)):
    """تسجيل رمز جهاز FCM لإشعارات الدفع."""
    await notification_service.register_device_token(
        user_id=str(current.id),
        token=payload.token,
        platform=payload.platform,
    )
    return None


@router.get("", response_model=list[NotificationOut])
async def list_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    unread_only: bool = False,
    patient_id: str | None = Query(None, description="تصفية حسب فرد العائلة النشط"),
    current=Depends(get_current_user),
):
    """قائمة إشعارات المستخدم — للمريض تُصفّى حسب فرد العائلة."""
    scoped_patient_id = await _resolve_patient_scope(current, patient_id)
    items = await notification_service.list_user_notifications(
        user_id=current.id,
        skip=skip,
        limit=limit,
        unread_only=unread_only,
        patient_id=scoped_patient_id,
    )
    return [_to_out(n) for n in items]


@router.get("/unread-count", response_model=UnreadCountOut)
async def get_unread_count(
    patient_id: str | None = Query(None, description="تصفية حسب فرد العائلة النشط"),
    current=Depends(get_current_user),
):
    """عدد الإشعارات غير المقروءة لفرد العائلة النشط."""
    scoped_patient_id = await _resolve_patient_scope(current, patient_id)
    count = await notification_service.unread_count(
        user_id=current.id,
        patient_id=scoped_patient_id,
    )
    return UnreadCountOut(count=count)


@router.patch("/{notification_id}/read", response_model=NotificationOut)
async def mark_notification_read(notification_id: str, current=Depends(get_current_user)):
    """تعليم إشعار واحد كمقروء."""
    notif = await notification_service.mark_as_read(
        user_id=current.id,
        notification_id=notification_id,
    )
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    return _to_out(notif)


@router.post("/mark-all-read", response_model=UnreadCountOut)
async def mark_all_read(
    patient_id: str | None = Query(None, description="تعليم مقروء لفرد العائلة النشط فقط"),
    current=Depends(get_current_user),
):
    """تعليم إشعارات فرد العائلة كمقروءة."""
    scoped_patient_id = await _resolve_patient_scope(current, patient_id)
    updated = await notification_service.mark_all_as_read(
        user_id=current.id,
        patient_id=scoped_patient_id,
    )
    return UnreadCountOut(count=updated)


@router.post(
    "/broadcast",
    response_model=BroadcastResultOut,
    dependencies=[Depends(require_roles([Role.ADMIN, Role.RECEPTIONIST]))],
)
async def broadcast_general(payload: GeneralNotificationIn):
    """إرسال تنبيه عام لجميع المرضى (مدير / استقبال)."""
    sent = await notification_service.notify_all_patients(
        title=payload.title,
        body=payload.body,
    )
    return BroadcastResultOut(sent_count=sent)
