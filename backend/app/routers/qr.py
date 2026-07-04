from fastapi import APIRouter, Depends
from beanie.operators import In

from app.schemas import QRScanOut, DoctorOut
from app.security import require_roles
from app.constants import Role
from app.utils.patient_out import build_patient_out

router = APIRouter(prefix="/qr", tags=["qr"])


@router.get("/scan", response_model=QRScanOut)
async def scan(code: str, current=Depends(require_roles([Role.ADMIN, Role.DOCTOR, Role.RECEPTIONIST]))):
    """المسح عبر رمز المريض لإظهار ملفه (للطبيب والمدير وموظف الاستقبال)."""
    from app.models import Patient, Doctor, User
    from app.utils.logger import get_logger
    from beanie import PydanticObjectId as OID

    logger = get_logger("qr_scan")
    logger.info(f"QR scan request - code: {code}, user_id: {current.id}")

    patient = await Patient.find_one(Patient.qr_code_data == code)

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

    return {
        "patient": build_patient_out(patient, u),
        "doctors": doctors_list,
    }
