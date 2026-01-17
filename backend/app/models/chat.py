from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone
from typing import Optional

from app.constants import Role


class ChatRoom(Document):
    """غرفة محادثة واحدة لكل زوج (طبيب، مريض)."""
    # User-level identifiers (new canonical keys)
    doctor_user_id: Indexed(OID) | None = None
    patient_user_id: Indexed(OID) | None = None

    # Legacy references to doctor/patient documents (kept for compatibility)
    doctor_id: Indexed(OID) | None = None
    patient_id: Indexed(OID) | None = None

    class Settings:
        name = "chat_rooms"


class ChatMessage(Document):
    """رسالة دردشة محفوظة."""
    room_id: Indexed(OID)
    sender_user_id: Indexed(OID) | None = None
    sender_role: Indexed(str) = Role.PATIENT
    content: str
    imageUrl: Optional[str] = None
    is_read: bool = False
    created_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "chat_messages"
