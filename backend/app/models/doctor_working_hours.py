from beanie import Document, Indexed
from beanie import PydanticObjectId as OID
from pydantic import Field, field_validator
from datetime import datetime, timezone
from typing import Optional


class DoctorWorkingHours(Document):
    """أوقات عمل الطبيب لكل يوم من أيام الأسبوع."""
    doctor_id: Indexed(OID)
    day_of_week: Indexed(int)  # 0=Sunday, 1=Monday, ..., 6=Saturday
    start_time: str  # HH:MM format
    end_time: str  # HH:MM format
    is_working: bool = True
    slot_duration: int = 30  # Duration in minutes (15, 30, 45, 60...)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    @field_validator('day_of_week')
    @classmethod
    def validate_day_of_week(cls, v: int) -> int:
        if not (0 <= v <= 6):
            raise ValueError('day_of_week must be between 0 and 6')
        return v

    @field_validator('start_time', 'end_time')
    @classmethod
    def validate_time_format(cls, v: str) -> str:
        import re
        if not re.match(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$', v):
            raise ValueError('Time must be in HH:MM format')
        return v

    @field_validator('slot_duration')
    @classmethod
    def validate_slot_duration(cls, v: int) -> int:
        if v < 15 or v > 120:
            raise ValueError('slot_duration must be between 15 and 120 minutes')
        if v % 15 != 0:
            raise ValueError('slot_duration must be a multiple of 15 minutes')
        return v

    def model_post_init(self, __context) -> None:
        """Validate that start_time is before end_time."""
        if self.is_working:
            start_parts = self.start_time.split(':')
            end_parts = self.end_time.split(':')
            start_minutes = int(start_parts[0]) * 60 + int(start_parts[1])
            end_minutes = int(end_parts[0]) * 60 + int(end_parts[1])
            if start_minutes >= end_minutes:
                raise ValueError('start_time must be before end_time')

    class Settings:
        name = "doctor_working_hours"
        indexes = [
            [("doctor_id", 1), ("day_of_week", 1)],  # Unique compound index
        ]

