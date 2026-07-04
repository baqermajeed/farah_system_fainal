from typing import Optional

from fastapi import HTTPException
from beanie import PydanticObjectId as OID

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
    imageUrl: Optional[str] = None,
) -> User:
    """Admin: create a staff user (Doctor/Receptionist/Photographer/CallCenter/Admin) بحساب username/password."""
    if role not in {Role.DOCTOR, Role.RECEPTIONIST, Role.PHOTOGRAPHER, Role.CALL_CENTER, Role.ADMIN}:
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
        imageUrl=imageUrl,
    )
    await user.insert()

    if role == Role.DOCTOR:
        await Doctor(user_id=user.id).insert()

    return user


async def create_patient_profile_for_user(
    *,
    user_id: OID,
    name: Optional[str],
    gender: Optional[str],
    age: Optional[int],
    city: Optional[str],
    visit_type: Optional[str] = None,
    consultation_type: Optional[str] = None,
    is_primary: bool = False,
    relationship: Optional[str] = None,
) -> Patient:
    """Create a new medical profile under an existing login account (family member)."""
    from os import urandom

    existing_count = await Patient.find(Patient.user_id == user_id).count()
    if existing_count == 0:
        is_primary = True
        if not relationship:
            relationship = "self"

    tmp_qr = f"tmp-{urandom(8).hex()}"
    patient = Patient(
        user_id=user_id,
        name=name,
        gender=gender,
        age=age,
        city=city,
        is_primary=is_primary,
        relationship=relationship or ("self" if is_primary else "child"),
        qr_code_data=tmp_qr,
        visit_type=visit_type,
        consultation_type=consultation_type,
    )
    await patient.insert()
    await ensure_patient_qr(patient)
    return patient


async def create_patient(
    *,
    phone: str,
    name: Optional[str],
    gender: Optional[str],
    age: Optional[int],
    city: Optional[str],
    visit_type: Optional[str] = None,
    consultation_type: Optional[str] = None,
    relationship: Optional[str] = None,
) -> Patient:
    """Create patient profile. If phone exists, add family member; else create User + first profile."""
    phone = phone.strip()
    existing_user = await User.find_one(User.phone == phone)

    if existing_user:
        if existing_user.role != Role.PATIENT:
            raise HTTPException(
                status_code=400,
                detail="رقم الهاتف مستخدم لحساب موظف/طبيب ولا يمكن إضافة مريض عليه",
            )
        return await create_patient_profile_for_user(
            user_id=existing_user.id,
            name=name,
            gender=gender,
            age=age,
            city=city,
            visit_type=visit_type,
            consultation_type=consultation_type,
            is_primary=False,
            relationship=relationship or "child",
        )

    user = User(
        phone=phone,
        name=name,
        role=Role.PATIENT,
        gender=gender,
        age=age,
        city=city,
    )
    await user.insert()

    return await create_patient_profile_for_user(
        user_id=user.id,
        name=name,
        gender=gender,
        age=age,
        city=city,
        visit_type=visit_type,
        consultation_type=consultation_type,
        is_primary=True,
        relationship=relationship or "self",
    )


async def migrate_legacy_patient_profiles() -> int:
    """Copy User profile fields onto primary Patient documents that lack them."""
    migrated = 0
    patients = await Patient.find({}).to_list()
    for patient in patients:
        is_primary = getattr(patient, "is_primary", True)
        relationship = (getattr(patient, "relationship", None) or "").lower()
        if not is_primary and relationship not in {"", "self"}:
            continue

        needs_save = False
        user = await User.get(patient.user_id)
        if not user:
            continue

        if patient.name is None and user.name is not None:
            patient.name = user.name
            needs_save = True
        if patient.gender is None and user.gender is not None:
            patient.gender = user.gender
            needs_save = True
        if patient.age is None and user.age is not None:
            patient.age = user.age
            needs_save = True
        if patient.city is None and user.city is not None:
            patient.city = user.city
            needs_save = True
        if patient.imageUrl is None and user.imageUrl is not None:
            patient.imageUrl = user.imageUrl
            needs_save = True
        if getattr(patient, "is_primary", None) is None:
            patient.is_primary = True
            needs_save = True

        if needs_save:
            await patient.save()
            migrated += 1
    return migrated
