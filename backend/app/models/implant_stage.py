from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone


class ImplantStage(Document):
    """مرحلة زراعة الأسنان للمريض.

    ملاحظة حول التوافق:
    - الحقل doctor_id أُضيف لاحقًا لعزل مراحل الزراعة بين الأطباء.
    - السجلات القديمة قد لا تحتوي على قيمة لهذا الحقل (None)،
      وفي هذه الحالة يمكن معالجتها كمحتوى "قديم" مشترك أو ترقيتها لاحقًا.
    """

    patient_id: Indexed(OID)
    # الطبيب المسؤول عن هذه السلسلة من المراحل (لكل طبيب سلسلة مستقلة لنفس المريض)
    doctor_id: Indexed(OID) | None = None
    stage_name: Indexed(str)  # اسم المرحلة من القائمة الثابتة
    scheduled_at: Indexed(datetime)  # تاريخ ووقت الموعد
    is_completed: bool = False  # حالة الإكمال
    appointment_id: OID | None = None  # معرف الموعد المرتبط (اختياري)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "implant_stages"
