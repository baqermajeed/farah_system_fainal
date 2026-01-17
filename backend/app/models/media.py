from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone

class GalleryImage(Document):
    """صورة مرفوعة للمريض مع ملاحظة اختيارية."""
    patient_id: Indexed(OID)
    uploaded_by_user_id: Indexed(OID) | None = None
    doctor_id: Indexed(OID) | None = None
    note: str | None = None
    image_path: str
    created_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "gallery_images"
