from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime, timezone
from typing import List

from app.schemas import (
    ImplantStageOut,
    ImplantStageDateUpdate,
    ImplantStagesResponse,
)
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services import implant_stage_service
from app.models import User, Doctor, Patient
from beanie import PydanticObjectId as OID

router = APIRouter(
    prefix="/patients/{patient_id}/implant-stages",
    tags=["implant-stages"],
)


@router.get("", response_model=ImplantStagesResponse)
async def get_implant_stages(
    patient_id: str,
    current=Depends(get_current_user),
):
    """جلب مراحل زراعة الأسنان للمريض.

    - الطبيب: يرى فقط المراحل المرتبطة به هو لهذا المريض.
    - المريض والاستقبال: يرون جميع المراحل المسجَّلة لهذا المريض (بغض النظر عن الطبيب).
    """
    # التحقق من أن المستخدم لديه صلاحية الوصول للمريض
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    doctor_id_for_query: str | None = None

    # التحقق من الصلاحيات: الطبيب، المريض، أو الاستقبال
    user_type = current.role
    if user_type == Role.DOCTOR:
        # الطبيب: يجب أن يكون المريض في قائمة أطبائه
        doctor = await Doctor.find_one(Doctor.user_id == current.id)
        if not doctor or OID(doctor.id) not in patient.doctor_ids:
            raise HTTPException(status_code=403, detail="Not your patient")
        doctor_id_for_query = str(doctor.id)
    elif user_type == Role.PATIENT:
        # المريض: يجب أن يكون المريض نفسه
        if str(patient.user_id) != str(current.id):
            raise HTTPException(status_code=403, detail="Not your profile")
    elif user_type != Role.RECEPTIONIST:
        # الاستقبال: مسموح، لكن غيرهم غير مسموح
        raise HTTPException(status_code=403, detail="Access denied")

    stages = await implant_stage_service.get_implant_stages(
        patient_id,
        doctor_id_for_query,
    )

    # تحويل إلى ImplantStageOut
    stage_outs = [
        ImplantStageOut(
            id=str(stage.id),
            patient_id=str(stage.patient_id),
            stage_name=stage.stage_name,
            scheduled_at=stage.scheduled_at.isoformat()
            if stage.scheduled_at
            else datetime.now(timezone.utc).isoformat(),
            is_completed=stage.is_completed,
            appointment_id=str(stage.appointment_id)
            if stage.appointment_id
            else None,
            created_at=stage.created_at.isoformat()
            if stage.created_at
            else datetime.now(timezone.utc).isoformat(),
            updated_at=stage.updated_at.isoformat()
            if stage.updated_at
            else datetime.now(timezone.utc).isoformat(),
        )
        for stage in stages
    ]

    return ImplantStagesResponse(stages=stage_outs)


@router.post("/initialize", response_model=ImplantStagesResponse)
async def initialize_implant_stages(
    patient_id: str,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """تهيئة مراحل زراعة الأسنان للمريض (للطبيب فقط)."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    # التحقق من أن الطبيب هو طبيب المريض
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor or OID(doctor.id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    # الحصول على تاريخ تسجيل المريض
    from app.models import User
    user = await User.get(patient.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    registration_date = user.created_at if user.created_at else datetime.now(timezone.utc)
    
    stages = await implant_stage_service.initialize_implant_stages(
        patient_id, 
        registration_date, 
        str(doctor.id)
    )
    
    # تحويل إلى ImplantStageOut
    stage_outs = [
        ImplantStageOut(
            id=str(stage.id),
            patient_id=str(stage.patient_id),
            stage_name=stage.stage_name,
            scheduled_at=stage.scheduled_at.isoformat() if stage.scheduled_at else datetime.now(timezone.utc).isoformat(),
            is_completed=stage.is_completed,
            appointment_id=str(stage.appointment_id) if stage.appointment_id else None,
            created_at=stage.created_at.isoformat() if stage.created_at else datetime.now(timezone.utc).isoformat(),
            updated_at=stage.updated_at.isoformat() if stage.updated_at else datetime.now(timezone.utc).isoformat(),
        )
        for stage in stages
    ]
    
    return ImplantStagesResponse(stages=stage_outs)


@router.put("/{stage_name}/date", response_model=ImplantStageOut)
async def update_stage_date(
    patient_id: str,
    stage_name: str,
    date_update: ImplantStageDateUpdate,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """تحديث تاريخ مرحلة زراعة (للطبيب فقط)."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    # التحقق من أن الطبيب هو طبيب المريض
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor or OID(doctor.id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    # تحويل التاريخ من ISO string إلى datetime
    try:
        new_date = datetime.fromisoformat(date_update.scheduled_at.replace('Z', '+00:00'))
        if new_date.tzinfo is None:
            new_date = new_date.replace(tzinfo=timezone.utc)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {e}")
    
    stage = await implant_stage_service.update_stage_date(
        patient_id,
        stage_name,
        new_date,
        str(doctor.id)
    )
    
    return ImplantStageOut(
        id=str(stage.id),
        patient_id=str(stage.patient_id),
        stage_name=stage.stage_name,
        scheduled_at=stage.scheduled_at.isoformat() if stage.scheduled_at else datetime.now(timezone.utc).isoformat(),
        is_completed=stage.is_completed,
        appointment_id=str(stage.appointment_id) if stage.appointment_id else None,
        created_at=stage.created_at.isoformat() if stage.created_at else datetime.now(timezone.utc).isoformat(),
        updated_at=stage.updated_at.isoformat() if stage.updated_at else datetime.now(timezone.utc).isoformat(),
    )


@router.post("/{stage_name}/complete", response_model=ImplantStageOut)
async def complete_stage(
    patient_id: str,
    stage_name: str,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """إكمال مرحلة زراعة (للطبيب فقط)."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    # التحقق من أن الطبيب هو طبيب المريض
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor or OID(doctor.id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    stage = await implant_stage_service.complete_stage(
        patient_id,
        stage_name,
        str(doctor.id)
    )
    
    return ImplantStageOut(
        id=str(stage.id),
        patient_id=str(stage.patient_id),
        stage_name=stage.stage_name,
        scheduled_at=stage.scheduled_at.isoformat() if stage.scheduled_at else datetime.now(timezone.utc).isoformat(),
        is_completed=stage.is_completed,
        appointment_id=str(stage.appointment_id) if stage.appointment_id else None,
        created_at=stage.created_at.isoformat() if stage.created_at else datetime.now(timezone.utc).isoformat(),
        updated_at=stage.updated_at.isoformat() if stage.updated_at else datetime.now(timezone.utc).isoformat(),
    )


@router.post("/{stage_name}/uncomplete", response_model=ImplantStageOut)
async def uncomplete_stage(
    patient_id: str,
    stage_name: str,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """إلغاء إكمال مرحلة زراعة (للطبيب فقط)."""
    patient = await Patient.get(OID(patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    
    # التحقق من أن الطبيب هو طبيب المريض
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor or OID(doctor.id) not in patient.doctor_ids:
        raise HTTPException(status_code=403, detail="Not your patient")
    
    stage = await implant_stage_service.uncomplete_stage(
        patient_id,
        stage_name,
        str(doctor.id)
    )
    
    return ImplantStageOut(
        id=str(stage.id),
        patient_id=str(stage.patient_id),
        stage_name=stage.stage_name,
        scheduled_at=stage.scheduled_at.isoformat() if stage.scheduled_at else datetime.now(timezone.utc).isoformat(),
        is_completed=stage.is_completed,
        appointment_id=str(stage.appointment_id) if stage.appointment_id else None,
        created_at=stage.created_at.isoformat() if stage.created_at else datetime.now(timezone.utc).isoformat(),
        updated_at=stage.updated_at.isoformat() if stage.updated_at else datetime.now(timezone.utc).isoformat(),
    )

