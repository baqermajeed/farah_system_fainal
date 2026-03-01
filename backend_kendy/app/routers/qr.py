from fastapi import APIRouter, Depends
from beanie.operators import In

from app.schemas import QRScanOut, PatientOut, DoctorOut
from app.security import require_roles, get_current_user
from app.constants import Role
from app.utils.patient_profile import build_doctor_profile_map

router = APIRouter(prefix="/qr", tags=["qr"])

@router.get("/scan", response_model=QRScanOut)
async def scan(code: str, current=Depends(require_roles([Role.ADMIN, Role.DOCTOR, Role.RECEPTIONIST]))):
    """المسح عبر رمز المريض لإظهار ملفه (للطبيب والمدير وموظف الاستقبال)."""
    from app.models import Patient, Doctor, User
    from app.utils.logger import get_logger
    from beanie import PydanticObjectId as OID
    
    logger = get_logger("qr_scan")
    logger.info(f"QR scan request - code: {code}, user_id: {current.id}")
    
    # البحث أولاً بـ qr_code_data
    patient = await Patient.find_one(Patient.qr_code_data == code)
    
    # إذا لم يُوجد، جرب البحث بـ ObjectId مباشرة (للتوافق مع QR codes القديمة)
    if not patient:
        try:
            patient = await Patient.get(OID(code))
            logger.info(f"Patient found by ObjectId: {patient.id}")
        except Exception:
            logger.warning(f"Patient not found for QR code: {code} (tried qr_code_data and ObjectId)")
            return {"patient": None, "doctors": []}
    
    logger.info(f"Patient found: {patient.id}, user_id: {patient.user_id}")
    u = await User.get(patient.user_id)
    if not u:
        logger.warning(f"User not found for patient: {patient.id}, user_id: {patient.user_id}")
        return {"patient": None, "doctors": []}
    
    # جلب معلومات الأطباء المرتبطين بالمريض
    doctors_list = []
    if patient.doctor_ids:
        doctors = await Doctor.find(In(Doctor.id, patient.doctor_ids)).to_list()
        user_ids = list({d.user_id for d in doctors if d.user_id})
        users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
        user_map = {user.id: user for user in users}
        
        for doctor in doctors:
            doctor_user = user_map.get(doctor.user_id)
            if doctor_user:
                doctors_list.append(DoctorOut(
                    id=str(doctor.id),
                    user_id=str(doctor.user_id),
                    name=doctor_user.name,
                    phone=doctor_user.phone,
                    imageUrl=doctor_user.imageUrl,
                ))
    
    # محاولة الحصول على treatment_type من doctor_profiles إذا كان patient.treatment_type None
    treatment_type = patient.treatment_type
    if not treatment_type and patient.doctor_profiles:
        # نأخذ treatment_type من أول doctor_profile موجود
        for profile in patient.doctor_profiles.values():
            if profile and profile.treatment_type:
                treatment_type = profile.treatment_type
                break
    
    return {
        "patient": PatientOut(
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
            imageUrl=u.imageUrl,
            created_at=patient.created_at.isoformat() if getattr(patient, "created_at", None) else None,
        ),
        "doctors": doctors_list,
    }
