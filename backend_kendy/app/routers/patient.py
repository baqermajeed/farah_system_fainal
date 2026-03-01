from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime, timezone
from typing import List
import asyncio

from app.schemas import PatientOut, PatientAppointmentsOut, AppointmentOut, NoteOut, GalleryOut, DoctorOut, PatientUpdate
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services import patient_service
from app.models import Patient, Doctor, User
from app.utils.qrcode_gen import ensure_patient_qr
from app.utils.patient_profile import build_doctor_profile_map
from beanie import PydanticObjectId as OID

router = APIRouter(prefix="/patient", tags=["patient"], dependencies=[Depends(require_roles([Role.PATIENT]))])

@router.get("/me", response_model=PatientOut)
async def my_profile(current=Depends(get_current_user)):
    """بيانات حساب المريض، بما فيها الأطباء المعينون والباركود الخاص به."""
    # fetch patient profile by linking from user
    patient = await Patient.find_one(Patient.user_id == current.id)
    if patient and not patient.qr_code_data:
        await ensure_patient_qr(patient)
    u = current
    p = patient

    # للمريض نعرض نوع علاج "عام" مشتق من أول doctor_profile لديه نوع علاج،
    # ولا نعتمد على patient.treatment_type بعد الآن.
    treatment_type: str | None = None
    if p and p.doctor_profiles:
        for profile in p.doctor_profiles.values():
            if profile and profile.treatment_type:
                treatment_type = profile.treatment_type
                break
    return PatientOut(
        id=str(p.id),
        user_id=str(p.user_id),
        name=u.name,
        phone=u.phone,
        gender=u.gender,
        age=u.age,
        city=u.city,
        treatment_type=treatment_type,
        visit_type=getattr(p, "visit_type", None),
        consultation_type=getattr(p, "consultation_type", None),
        payment_methods=getattr(p, "payment_methods", None),
        doctor_ids=[str(did) for did in p.doctor_ids],
        doctor_profiles=build_doctor_profile_map(p),
        qr_code_data=p.qr_code_data,
        qr_image_path=p.qr_image_path,
        imageUrl=u.imageUrl,
        created_at=p.created_at.isoformat() if getattr(p, "created_at", None) else None,
    )

@router.put("/me", response_model=PatientOut)
async def update_my_profile(data: PatientUpdate, current=Depends(get_current_user)):
    """تحديث بيانات حساب المريض."""
    # fetch patient profile by linking from user
    patient = await Patient.find_one(Patient.user_id == current.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    
    # current is already the User object from get_current_user
    u = current
    
    # Update user fields
    if data.name is not None:
        u.name = data.name
    if data.gender is not None:
        u.gender = data.gender
    if data.age is not None:
        u.age = data.age
    if data.city is not None:
        u.city = data.city
    
    await u.save()
    
    # Return updated patient
    if patient and not patient.qr_code_data:
        await ensure_patient_qr(patient)
    
    # إعادة حساب نوع العلاج العام للمريض بنفس منطق /patient/me
    treatment_type: str | None = None
    if patient and patient.doctor_profiles:
        for profile in patient.doctor_profiles.values():
            if profile and profile.treatment_type:
                treatment_type = profile.treatment_type
                break

    return PatientOut(
        id=str(patient.id),
        user_id=str(patient.user_id),
        name=u.name,
        phone=u.phone,
        gender=u.gender,
        age=u.age,
        city=u.city,
        treatment_type=treatment_type,
        visit_type=getattr(patient, "visit_type", None),
        consultation_type=getattr(patient, "consultation_type", None),
        payment_methods=getattr(patient, "payment_methods", None),
        doctor_ids=[str(did) for did in patient.doctor_ids],
        doctor_profiles=build_doctor_profile_map(patient),
        qr_code_data=patient.qr_code_data,
        qr_image_path=patient.qr_image_path,
        created_at=patient.created_at.isoformat() if getattr(patient, "created_at", None) else None,
    )

@router.get("/doctor", response_model=DoctorOut)
async def my_doctor(current=Depends(get_current_user)):
    """معلومات الطبيب المرتبط بالمريض (أول طبيب في القائمة)."""
    patient = await Patient.find_one(Patient.user_id == current.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    
    if not patient.doctor_ids:
        raise HTTPException(status_code=404, detail="No doctor assigned")
    
    # Return the first doctor in the list
    doctor = await Doctor.get(patient.doctor_ids[0])
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
    
    user = await User.get(doctor.user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Doctor user not found")
    
    return DoctorOut(
        id=str(doctor.id),
        user_id=str(doctor.user_id),
        name=user.name,
        phone=user.phone,
        imageUrl=user.imageUrl,
    )

@router.get("/doctors", response_model=List[DoctorOut])
async def my_doctors(current=Depends(get_current_user)):
    """قائمة الأطباء المرتبطين بالمريض."""
    from beanie.operators import In
    patient = await Patient.find_one(Patient.user_id == current.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    
    if not patient.doctor_ids:
        return []
    
    doctors = await Doctor.find(In(Doctor.id, patient.doctor_ids)).to_list()
    user_ids = list({d.user_id for d in doctors if d.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}
    
    out: List[DoctorOut] = []
    for d in doctors:
        u = user_map.get(d.user_id)
        if u:
            out.append(DoctorOut(
                id=str(d.id),
                user_id=str(d.user_id),
                name=u.name,
                phone=u.phone,
                imageUrl=u.imageUrl,
            ))
    return out

@router.get("/appointments", response_model=PatientAppointmentsOut)
async def my_appointments(current=Depends(get_current_user)):
    """
    مواعيد المريض في حسابه.
    يعرض جميع المواعيد بما فيها المكتملة والملغية.
    مقسّمة حسب الطبيب الأساسي والثانوي.
    """
    # الحصول على ملف المريض المرتبط بهذا المستخدم
    patient = await Patient.find_one(Patient.user_id == current.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")

    primary, secondary = await patient_service.list_patient_appointments_grouped(
        patient_id=str(patient.id)
    )
    
    # تحويل المواعيد إلى AppointmentOut مع جلب patient_name و doctor_name
    async def build_appointment_out(a):
        # جلب بيانات المريض
        patient_name = None
        try:
            apt_patient = await Patient.get(a.patient_id)
            if apt_patient:
                user = await User.get(apt_patient.user_id)
                if user:
                    patient_name = user.name
        except Exception:
            pass
        
        # جلب بيانات الطبيب
        doctor_name = None
        try:
            doctor = await Doctor.get(a.doctor_id)
            if doctor:
                user = await User.get(doctor.user_id)
                if user:
                    doctor_name = user.name
        except Exception:
            pass
        
        return AppointmentOut(
            id=str(a.id),
            patient_id=str(a.patient_id),
            patient_name=patient_name,
            doctor_id=str(a.doctor_id),
            doctor_name=doctor_name,
            scheduled_at=a.scheduled_at.isoformat() if a.scheduled_at else datetime.now(timezone.utc).isoformat(),
            note=a.note,
            image_path=a.image_path,
            image_paths=a.image_paths or [],
            status=a.status,
        )
    
    # استخدام asyncio.gather لتنفيذ جميع العمليات بشكل متوازي
    import asyncio
    primary_out = await asyncio.gather(*[build_appointment_out(a) for a in primary])
    secondary_out = await asyncio.gather(*[build_appointment_out(a) for a in secondary])
    
    return PatientAppointmentsOut(
        primary=primary_out,
        secondary=secondary_out,
    )

@router.get("/notes", response_model=list[NoteOut])
async def my_notes(current=Depends(get_current_user)):
    """سجلات علاجي (القسم الأول)."""
    patient = await Patient.find_one(Patient.user_id == current.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")

    notes = await patient_service.list_notes_for_patient(
        patient_id=str(patient.id)
    )
    return [NoteOut.model_validate(n) for n in notes]

@router.get("/gallery", response_model=list[GalleryOut])
async def my_gallery(current=Depends(get_current_user)):
    """معرض صوري (القسم الثالث) كما يراه المريض.

    المريض لا يرى الصور التي رفعها الأطباء أو موظفو الاستقبال،
    وإنما يمكنه رؤية الصور التي رفعها مستخدمون آخرون مثل المصور أو نفسه فقط.
    """
    patient = await Patient.find_one(Patient.user_id == current.id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient profile not found")

    # المريض لا يرى الصور التي رفعها الأطباء أو موظفي الاستقبال
    gallery = await patient_service.list_gallery_for_patient_public(
        patient_id=str(patient.id),
        skip=0,
        limit=None,
    )
    result = []
    for g in gallery:
        try:
            result.append(
                GalleryOut(
                    id=str(g.id),
                    patient_id=str(g.patient_id),
                    image_path=g.image_path,
                    note=g.note,
                    created_at=g.created_at.isoformat() if g.created_at else datetime.now(timezone.utc).isoformat(),
                )
            )
        except Exception as e:
            # Skip this image if there's an error
            continue
    return result
