from fastapi import APIRouter, Depends, HTTPException, Query

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


def _to_out(n) -> NotificationOut:
    return NotificationOut(
        id=str(n.id),
        title=n.title,
        body=n.body,
        type=getattr(n, "type", None) or "general",
        data=getattr(n, "data", None) or {},
        is_read=bool(getattr(n, "is_read", False)),
        sent_at=n.sent_at.isoformat() if n.sent_at else "",
    )


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
    current=Depends(get_current_user),
):
    """قائمة إشعارات المستخدم الحالي."""
    items = await notification_service.list_user_notifications(
        user_id=current.id,
        skip=skip,
        limit=limit,
        unread_only=unread_only,
    )
    return [_to_out(n) for n in items]


@router.get("/unread-count", response_model=UnreadCountOut)
async def get_unread_count(current=Depends(get_current_user)):
    """عدد الإشعارات غير المقروءة."""
    count = await notification_service.unread_count(user_id=current.id)
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
async def mark_all_read(current=Depends(get_current_user)):
    """تعليم كل الإشعارات كمقروءة."""
    updated = await notification_service.mark_all_as_read(user_id=current.id)
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
