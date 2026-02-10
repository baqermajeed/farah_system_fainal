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
    active_on_assigned_day: bool = False
    payment_methods: list[str] = Field(default_factory=list)

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

    # هل المريض جديد أم مراجع قديم (يُحدد عند الإنشاء من الاستقبال/الطبيب)
    visit_type: str | None = None

    # هل معاينة المريض مدفوعة أم مجانية (يُحدد عند الإنشاء من الاستقبال/الطبيب)
    consultation_type: str | None = None

    # طرق الدفع المتفق عليها مع المريض (مثلاً: نقد، ماستر كارد، كمبيالة، تعهد)
    payment_methods: list[str] = Field(default_factory=list)

    qr_code_data: Indexed(str, unique=True) = ""
    qr_image_path: str | None = None

    # تاريخ تسجيل المريض (يُملأ تلقائيًا عند إنشاء السجل)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "patients"
