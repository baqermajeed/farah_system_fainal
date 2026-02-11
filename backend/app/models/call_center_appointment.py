from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone


class CallCenterAppointment(Document):
    """موعد أولي من مركز الاتصالات (غير مرتبط بملف مريض)."""

    patient_name: str
    patient_phone: Indexed(str)
    scheduled_at: Indexed(datetime)

    created_by_user_id: Indexed(OID)
    created_by_username: str

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "call_center_appointments"

