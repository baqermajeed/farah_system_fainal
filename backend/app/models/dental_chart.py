from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import BaseModel, Field
from datetime import datetime, timezone
from typing import Dict, List, Optional
from pymongo import IndexModel, ASCENDING


class DentalNoteEntry(BaseModel):
    """ملاحظة على سن معيّن — مطابق لـ _DentalNoteEntry في الواجهة."""

    text: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class DentalChart(Document):
    """مخطط الأسنان (FDI) لمريض عند طبيب معيّن.

    كل طبيب له مخطط مستقل لنفس المريض (مثل implant_stages).
    البنية مطابقة لكاش الواجهة:
      chart: { "11": ["حشوة", "حشوة تجميلية"], ... }
      notes: { "11": [{ text, created_at }, ...], ... }
    """

    patient_id: Indexed(OID)
    doctor_id: Indexed(OID)
    # رقم السن (FDI) -> قائمة الحالات (أساسية + فرعية)
    chart: Dict[str, List[str]] = Field(default_factory=dict)
    # رقم السن -> ملاحظات متعددة مرتبة زمنياً
    notes: Dict[str, List[DentalNoteEntry]] = Field(default_factory=dict)
    # السن المحدد في الواجهة (اختياري)
    selected_tooth: Optional[str] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "dental_charts"
        indexes = [
            IndexModel(
                [("patient_id", ASCENDING), ("doctor_id", ASCENDING)],
                unique=True,
                name="patient_doctor_dental_chart_unique",
            ),
        ]
