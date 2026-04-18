from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import List, Optional

class Appointment(Document):
    """موعد مريض لدى طبيب."""
    patient_id: Indexed(OID)
    doctor_id: Indexed(OID)
    scheduled_at: Indexed(datetime)
    previous_scheduled_at: Optional[datetime] = None  # لتتبع التعديلات على التاريخ/الوقت
    note: str | None = None
    image_path: str | None = None  # للتوافق مع البيانات القديمة
    image_paths: List[str] = Field(default_factory=list)  # قائمة الصور الجديدة
    # الحالات الجديدة: pending (قيد الانتظار), completed (مكتمل), cancelled (ملغي), late (متأخر)
    status: Indexed(str) = "pending"  # pending|completed|cancelled|late
    stage_name: str | None = None  # اسم مرحلة الزراعة المرتبطة (إن وجدت)
    remind_3d_sent: bool = False
    remind_1d_sent: bool = False
    remind_day_sent: bool = False
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "appointments"
