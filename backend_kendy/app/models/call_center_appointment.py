from typing import Optional
from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone


class CallCenterAppointment(Document):
    """موعد أولي من مركز الاتصالات (غير مرتبط بملف مريض)."""

    patient_name: str
    patient_phone: Indexed(str)
    scheduled_at: Indexed(datetime)

    governorate: str = ""   # المحافظة (محافظات العراق)
    platform: str = ""      # المنصة (انستكرام، واتساب، تيك توك، فيسبوك، اتصال)
    note: str = ""          # ملاحظة اختيارية من موظف الاتصالات عند الإضافة

    created_by_user_id: Indexed(OID)
    created_by_username: str

    # pending = لم يُقبل بعد، accepted = قبله موظف الاستقبال (يُخفى من قائمة الاستقبال ويُعرض بلون أخضر في حساب الـ call center)
    status: str = "pending"  # "pending" | "accepted"
    # تاريخ قبول الموعد من الاستقبال (للإحصائيات حسب شهر القبول)
    accepted_at: Optional[datetime] = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "call_center_appointments"
