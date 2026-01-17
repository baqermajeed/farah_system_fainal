from typing import Optional

from fastapi import HTTPException

from app.constants import Role
from app.models import User, Doctor, Patient
from app.security import hash_password
from app.utils.qrcode_gen import ensure_patient_qr


async def create_staff_user(
    *,
    phone: str,
    username: str,
    password: str,
    name: Optional[str],
    role: Role,
) -> User:
    """Admin: create a staff user (Doctor/Receptionist/Photographer/Admin) بحساب username/password."""
    if role not in {Role.DOCTOR, Role.RECEPTIONIST, Role.PHOTOGRAPHER, Role.ADMIN}:
        raise HTTPException(status_code=400, detail="Invalid role for staff creation")

    if await User.find_one(User.phone == phone):
        raise HTTPException(status_code=400, detail="Phone already exists")
    if await User.find_one(User.username == username):
        raise HTTPException(status_code=400, detail="Username already exists")

    user = User(
        phone=phone,
        name=name,
        role=role,
        username=username,
        password_hash=hash_password(password),
    )
    await user.insert()

    if role == Role.DOCTOR:
        await Doctor(user_id=user.id).insert()

    # لا ننشئ مرضى هنا؛ المرضى يتم إنشاؤهم عبر OTP أو create_patient
    return user


async def create_patient(
    *,
    phone: str,
    name: Optional[str],
    gender: Optional[str],
    age: Optional[int],
    city: Optional[str],
) -> Patient:
    """Create a full patient (User + Patient profile) for reception/admin flows."""
    # تأكد أن رقم الهاتف غير مستخدم
    if await User.find_one(User.phone == phone):
        raise HTTPException(status_code=400, detail="Phone already exists")

    # أنشئ مستخدمًا بدور مريض
    user = User(
        phone=phone,
        name=name,
        role=Role.PATIENT,
        gender=gender,
        age=age,
        city=city,
    )
    await user.insert()

    # أنشئ ملف المريض + QR
    from os import urandom

    tmp_qr = f"tmp-{urandom(8).hex()}"
    patient = Patient(user_id=user.id, qr_code_data=tmp_qr)
    await patient.insert()
    await ensure_patient_qr(patient)
    return patient

