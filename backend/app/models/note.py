from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import List, Optional
from pymongo import IndexModel, ASCENDING

class TreatmentNote(Document):
    """سجل علاجي نصي مع صور اختيارية."""
    patient_id: Indexed(OID)
    doctor_id: Indexed(OID)
    note: str | None = None
    image_path: str | None = None  # للتوافق مع البيانات القديمة
    image_paths: List[str] = Field(default_factory=list)  # قائمة الصور الجديدة
    # مفتاح عملية العميل لمنع التكرار عند إعادة محاولة الرفع (at-least-once)
    client_operation_id: Optional[str] = None
    created_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "treatment_notes"
        indexes = [
            IndexModel(
                [("client_operation_id", ASCENDING)],
                unique=True,
                sparse=True,
                name="client_operation_id_unique_sparse",
            ),
        ]
