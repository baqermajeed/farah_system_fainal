from datetime import datetime, timezone

from beanie import Document, Indexed, PydanticObjectId as OID
from pydantic import Field


class DoctorPresence(Document):
    """Last heartbeat from a doctor's desktop app (HTTP presence)."""

    user_id: Indexed(OID, unique=True)
    last_seen_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )

    class Settings:
        name = "doctor_presence"
