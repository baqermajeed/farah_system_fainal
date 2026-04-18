from fastapi import APIRouter, Depends, HTTPException
from typing import List
from datetime import datetime, timezone

from app.routers.doctor import get_current_user
from app.services.doctor_working_hours_service import DoctorWorkingHoursService
from app.schemas import WorkingHoursIn, WorkingHoursOut
from app.models import User, Doctor

router = APIRouter(prefix="/doctor", tags=["Doctor Working Hours"])
working_hours_service = DoctorWorkingHoursService()


async def _get_current_doctor_id(current_user: User) -> str:
    """Get doctor ID from current user."""
    doctor = await Doctor.find_one(Doctor.user_id == current_user.id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    return str(doctor.id)


@router.post("/working-hours", response_model=List[WorkingHoursOut])
async def set_working_hours(
    working_hours: List[WorkingHoursIn],
    current=Depends(get_current_user),
):
    """تحديد أوقات العمل للطبيب."""
    doctor_id = await _get_current_doctor_id(current)
    
    # Convert to dict format
    working_hours_list = []
    for wh in working_hours:
        working_hours_list.append({
            "dayOfWeek": wh.day_of_week,
            "startTime": wh.start_time,
            "endTime": wh.end_time,
            "isWorking": wh.is_working,
            "slotDuration": wh.slot_duration,
        })
    
    try:
        result = await working_hours_service.set_working_hours(
            doctor_id=str(doctor_id), working_hours_list=working_hours_list
        )
        
        return [
            WorkingHoursOut(
                id=str(wh.id),
                doctor_id=str(wh.doctor_id),
                day_of_week=wh.day_of_week,
                start_time=wh.start_time,
                end_time=wh.end_time,
                is_working=wh.is_working,
                slot_duration=wh.slot_duration,
                created_at=wh.created_at.isoformat() if wh.created_at else datetime.now(timezone.utc).isoformat(),
                updated_at=wh.updated_at.isoformat() if wh.updated_at else datetime.now(timezone.utc).isoformat(),
            )
            for wh in result
        ]
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error setting working hours: {str(e)}")


@router.get("/working-hours", response_model=List[WorkingHoursOut])
async def get_working_hours(current=Depends(get_current_user)):
    """جلب أوقات عمل الطبيب."""
    doctor_id = await _get_current_doctor_id(current)
    result = await working_hours_service.get_doctor_working_hours(str(doctor_id))
    return [
        WorkingHoursOut(
            id=str(wh.id),
            doctor_id=str(wh.doctor_id),
            day_of_week=wh.day_of_week,
            start_time=wh.start_time,
            end_time=wh.end_time,
            is_working=wh.is_working,
            slot_duration=wh.slot_duration,
            created_at=wh.created_at.isoformat() if wh.created_at else datetime.now(timezone.utc).isoformat(),
            updated_at=wh.updated_at.isoformat() if wh.updated_at else datetime.now(timezone.utc).isoformat(),
        )
        for wh in result
    ]


@router.get("/available-slots/{date}", response_model=List[str])
async def get_available_slots(
    date: str,
    current=Depends(get_current_user),
):
    """جلب الأوقات المتاحة لطبيب في يوم معين."""
    doctor_id = await _get_current_doctor_id(current)
    result = await working_hours_service.get_available_slots(
        doctor_id=str(doctor_id), date=date
    )
    return result


@router.delete("/working-hours", status_code=204)
async def delete_working_hours(current=Depends(get_current_user)):
    """حذف جميع أوقات عمل الطبيب."""
    doctor_id = await _get_current_doctor_id(current)
    await working_hours_service.delete_working_hours(str(doctor_id))
    return None

