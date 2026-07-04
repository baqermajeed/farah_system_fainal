from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import Optional
from pymongo import IndexModel, ASCENDING


class GalleryImage(Document):
    """صورة مرفوعة للمريض مع ملاحظة اختيارية."""
    patient_id: Indexed(OID)
    uploaded_by_user_id: Indexed(OID) | None = None
    doctor_id: Indexed(OID) | None = None
    note: str | None = None
    image_path: str
    # مفتاح عملية العميل لمنع تكرار الرفع عند إعادة المحاولة
    client_operation_id: Optional[str] = None
    created_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "gallery_images"
        indexes = [
            IndexModel(
                [("client_operation_id", ASCENDING)],
                unique=True,
                sparse=True,
                name="gallery_client_operation_id_unique_sparse",
            ),
        ]
