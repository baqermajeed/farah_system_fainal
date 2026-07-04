from typing import List
from beanie import Document, Indexed
from pydantic import BaseModel, Field
from datetime import datetime, timezone


class ReceptionQueueEntry(BaseModel):
    """شخص مضاف للطابور: الاسم ورقمه فقط (العرض والنداء محليان)."""

    number: int
    name: str


class ReceptionQueueDay(Document):
    """سجل طابور الاستقبال ليوم واحد — للأرشفة في السيرفر فقط."""

    date: Indexed(str, unique=True)  # YYYY-MM-DD
    total_count: int = 0
    entries: List[ReceptionQueueEntry] = Field(default_factory=list)
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "reception_queue_days"
