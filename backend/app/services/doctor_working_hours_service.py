from datetime import datetime, timezone
from typing import List, Optional, Dict
from fastapi import HTTPException
from beanie import PydanticObjectId as OID
from beanie.operators import In

from app.models import DoctorWorkingHours, User, Appointment


class DoctorWorkingHoursService:
    """خدمة إدارة أوقات عمل الأطباء."""

    async def set_working_hours(
        self, doctor_id: str, working_hours_list: List[Dict]
    ) -> List[DoctorWorkingHours]:
        """حفظ أو تحديث أوقات عمل الطبيب."""
        # التحقق من أن الطبيب موجود
        from app.models import Doctor
        doctor = await Doctor.get(OID(doctor_id))
        if not doctor:
            raise HTTPException(status_code=404, detail="Doctor not found")
        
        # حذف أوقات العمل السابقة
        await DoctorWorkingHours.find(
            DoctorWorkingHours.doctor_id == OID(doctor_id)
        ).delete()

        # إضافة أوقات العمل الجديدة
        new_working_hours = []
        for wh_data in working_hours_list:
            working_hour = DoctorWorkingHours(
                doctor_id=OID(doctor_id),
                day_of_week=wh_data['dayOfWeek'],
                start_time=wh_data['startTime'],
                end_time=wh_data['endTime'],
                is_working=wh_data.get('isWorking', True),
                slot_duration=wh_data.get('slotDuration', 30),
            )
            await working_hour.insert()
            new_working_hours.append(working_hour)

        return new_working_hours

    async def get_doctor_working_hours(
        self, doctor_id: str
    ) -> List[DoctorWorkingHours]:
        """جلب أوقات عمل الطبيب."""
        working_hours = await DoctorWorkingHours.find(
            DoctorWorkingHours.doctor_id == OID(doctor_id)
        ).sort("day_of_week").to_list()
        return working_hours

    async def get_available_slots(
        self, doctor_id: str, date: str
    ) -> List[str]:
        """جلب الأوقات المتاحة لطبيب في يوم معين."""
        from datetime import timedelta

        # Parse date
        try:
            appointment_date = datetime.fromisoformat(date.replace('Z', '+00:00'))
            if appointment_date.tzinfo is None:
                appointment_date = appointment_date.replace(tzinfo=timezone.utc)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

        day_of_week = appointment_date.weekday()  # 0=Monday, 6=Sunday
        # Convert to Sunday=0 format
        day_of_week = (day_of_week + 1) % 7

        # Get working hours for this day
        working_hours = await DoctorWorkingHours.find_one(
            DoctorWorkingHours.doctor_id == OID(doctor_id),
            DoctorWorkingHours.day_of_week == day_of_week,
            DoctorWorkingHours.is_working == True
        )

        if not working_hours:
            return []

        # Get booked appointments for this date
        start_of_day = appointment_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end_of_day = appointment_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        appointments = await Appointment.find(
            Appointment.doctor_id == OID(doctor_id),
            Appointment.scheduled_at >= start_of_day,
            Appointment.scheduled_at <= end_of_day,
            In(Appointment.status, ["scheduled", "completed"])
        ).to_list()

        booked_times = set()
        for apt in appointments:
            # Extract time from scheduled_at
            time_str = apt.scheduled_at.strftime('%H:%M')
            booked_times.add(time_str)

        # Generate available slots
        available_slots = []
        start_parts = working_hours.start_time.split(':')
        end_parts = working_hours.end_time.split(':')
        
        start_hour = int(start_parts[0])
        start_minute = int(start_parts[1])
        end_hour = int(end_parts[0])
        end_minute = int(end_parts[1])

        current_hour = start_hour
        current_minute = start_minute

        while (
            current_hour < end_hour or
            (current_hour == end_hour and current_minute < end_minute)
        ):
            time_str = f"{current_hour:02d}:{current_minute:02d}"
            
            if time_str not in booked_times:
                available_slots.append(time_str)

            # Add slot_duration
            total_minutes = current_hour * 60 + current_minute + working_hours.slot_duration
            current_hour = total_minutes // 60
            current_minute = total_minutes % 60

        return available_slots

    async def is_time_available(
        self, doctor_id: str, date: str, time: str
    ) -> Dict[str, any]:
        """التحقق من توفر وقت معين."""
        from datetime import timedelta

        # Parse date and time
        try:
            appointment_datetime = datetime.fromisoformat(
                f"{date}T{time}:00"
            )
            if appointment_datetime.tzinfo is None:
                appointment_datetime = appointment_datetime.replace(tzinfo=timezone.utc)
        except Exception:
            return {"available": False, "reason": "Invalid date or time format"}

        day_of_week = appointment_datetime.weekday()
        day_of_week = (day_of_week + 1) % 7  # Convert to Sunday=0

        # Check working hours
        working_hours = await DoctorWorkingHours.find_one(
            DoctorWorkingHours.doctor_id == OID(doctor_id),
            DoctorWorkingHours.day_of_week == day_of_week,
            DoctorWorkingHours.is_working == True
        )

        if not working_hours:
            return {"available": False, "reason": "الطبيب لا يعمل في هذا اليوم"}

        # Check if time is within working hours
        start_parts = working_hours.start_time.split(':')
        end_parts = working_hours.end_time.split(':')
        time_parts = time.split(':')

        start_minutes = int(start_parts[0]) * 60 + int(start_parts[1])
        end_minutes = int(end_parts[0]) * 60 + int(end_parts[1])
        requested_minutes = int(time_parts[0]) * 60 + int(time_parts[1])

        if requested_minutes < start_minutes or requested_minutes >= end_minutes:
            return {"available": False, "reason": "الوقت خارج ساعات العمل"}

        # Check if time aligns with slot_duration
        minutes_from_start = requested_minutes - start_minutes
        if minutes_from_start % working_hours.slot_duration != 0:
            return {
                "available": False,
                "reason": f"الوقت يجب أن يكون بفترات {working_hours.slot_duration} دقيقة"
            }

        # Check if already booked at this specific time
        existing_appointment = await Appointment.find_one(
            Appointment.doctor_id == OID(doctor_id),
            Appointment.scheduled_at == appointment_datetime,
            In(Appointment.status, ["scheduled", "completed"])
        )

        if existing_appointment:
            return {"available": False, "reason": "هذا الوقت محجوز بالفعل"}

        return {"available": True}

    async def delete_working_hours(self, doctor_id: str) -> bool:
        """حذف جميع أوقات عمل الطبيب."""
        result = await DoctorWorkingHours.find(
            DoctorWorkingHours.doctor_id == OID(doctor_id)
        ).delete()
        return True

