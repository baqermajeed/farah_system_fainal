from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from datetime import datetime, timezone
from pydantic import BaseModel, Field
from typing import Literal


class DoctorPatientProfile(BaseModel):
    """معلومات إضافية لكل طبيب مرتبط بالمريض."""
    treatment_type: str | None = None
    assigned_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    last_action_at: datetime | None = None
    status: Literal["pending", "active", "inactive"] = "pending"
    inactive_since: datetime | None = None

    class Config:
        arbitrary_types_allowed = True


class Patient(Document):
    """ملف المريض.
    - روابط للأطباء عبر قائمة المعرفات.
    - لكل مريض رمز QR ثابت وصورته.
    """
    user_id: Indexed(OID)
    doctor_ids: list[OID] = []  # قائمة معرفات الأطباء المرتبطين
    treatment_type: str | None = None
    doctor_profiles: dict[str, DoctorPatientProfile] = Field(default_factory=dict)

    qr_code_data: Indexed(str, unique=True) = ""
    qr_image_path: str | None = None

    class Settings:
        name = "patients"
