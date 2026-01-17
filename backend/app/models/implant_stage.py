from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone

class ImplantStage(Document):
    """مرحلة زراعة الأسنان للمريض."""
    patient_id: Indexed(OID)
    stage_name: Indexed(str)  # اسم المرحلة من القائمة الثابتة
    scheduled_at: Indexed(datetime)  # تاريخ ووقت الموعد
    is_completed: bool = False  # حالة الإكمال
    appointment_id: OID | None = None  # معرف الموعد المرتبط (اختياري)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "implant_stages"

