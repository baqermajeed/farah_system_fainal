from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import List

class TreatmentNote(Document):
    """سجل علاجي نصي مع صور اختيارية."""
    patient_id: Indexed(OID)
    doctor_id: Indexed(OID)
    note: str | None = None
    image_path: str | None = None  # للتوافق مع البيانات القديمة
    image_paths: List[str] = Field(default_factory=list)  # قائمة الصور الجديدة
    created_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "treatment_notes"
