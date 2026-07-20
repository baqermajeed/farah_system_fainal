from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import Any


class DeviceToken(Document):
    """رمز جهاز FCM لكل مستخدم وجهاز."""
    user_id: Indexed(OID)
    token: Indexed(str, unique=True)
    platform: str | None = None  # ios|android|web
    active: bool = True

    class Settings:
        name = "device_tokens"


class Notification(Document):
    """إشعار محفوظ للمستخدم (يُعرض في التطبيق ويُرسل عبر Push)."""
    user_id: Indexed(OID)
    # ملف طبي محدد (فرد عائلة). None = إشعار عام للحساب.
    patient_id: Indexed(OID) | None = None
    title: str
    body: str
    type: Indexed(str) = "general"
    data: dict[str, Any] = Field(default_factory=dict)
    is_read: bool = False
    sent_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "notifications"
