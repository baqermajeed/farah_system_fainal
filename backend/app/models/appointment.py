from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import List

class Appointment(Document):
    """موعد مريض لدى طبيب."""
    patient_id: Indexed(OID)
    doctor_id: Indexed(OID)
    scheduled_at: Indexed(datetime)
    note: str | None = None
    image_path: str | None = None  # للتوافق مع البيانات القديمة
    image_paths: List[str] = Field(default_factory=list)  # قائمة الصور الجديدة
    status: Indexed(str) = "scheduled"  # scheduled|completed|canceled|no_show
    stage_name: str | None = None  # اسم مرحلة الزراعة المرتبطة (إن وجدت)
    remind_3d_sent: bool = False
    remind_1d_sent: bool = False
    remind_day_sent: bool = False

    class Settings:
        name = "appointments"
