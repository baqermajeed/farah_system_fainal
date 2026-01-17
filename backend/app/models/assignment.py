from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field
from datetime import datetime, timezone

class AssignmentLog(Document):
    """سجل تحويل/تعيين مريض إلى طبيب."""
    patient_id: Indexed(OID)
    doctor_id: Indexed(OID)
    previous_doctor_id: Indexed(OID) | None = None
    assigned_by_user_id: Indexed(OID) | None = None
    kind: str  # primary | secondary
    assigned_at: Indexed(datetime) = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "assignment_logs"
