from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from app.database import get_db

class Doctor(Document):
    """ملف الطبيب (يرتبط بمستخدم)."""
    user_id: OID

    class Settings:
        name = "doctors"
