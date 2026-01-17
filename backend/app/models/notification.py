from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone

class DeviceToken(Document):
    """رمز جهاز FCM لكل مستخدم وجهاز."""
    user_id: Indexed(OID)
    token: Indexed(str, unique=True)
    platform: str | None = None  # ios|android|web
    active: bool = True

    class Settings:
        name = "device_tokens"

class Notification(Document):
    """إشعار مُرسَل (اختياري للاحتفاظ)."""
    user_id: Indexed(OID)
    title: str
    body: str
    sent_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "notifications"
