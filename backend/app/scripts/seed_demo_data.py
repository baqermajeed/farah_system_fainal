"""
Seed script to populate database with initial data
Creates: users, patients, appointments, treatment notes
"""
import asyncio
import sys
from datetime import datetime, timedelta, timezone

# Fix encoding for Windows console
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

from app.config import get_settings
from app.database import init_db
from app.constants import Role
from app.models import User, Patient, Doctor, Appointment, TreatmentNote
from app.services.admin_service import create_staff_user, create_patient
from app.services.patient_service import (
    assign_patient_doctors,
    create_appointment,
    create_note,
    set_treatment_type,
)


async def _create_or_get_staff(*, phone: str, username: str, password: str, name: str, role: Role) -> User:
    """Create staff user if not exists, return existing if found."""
    existing = await User.find_one(User.username == username)
    if existing:
        print(f"[SKIP] User '{username}' already exists")
        return existing
    
    try:
        user = await create_staff_user(
            phone=phone,
            username=username,
            password=password,
            name=name,
            role=role,
        )
        print(f"[OK] Created {role.value}: {name} ({username})")
        return user
    except Exception as e:
        print(f"[ERROR] Failed to create {username}: {e}")
        existing = await User.find_one(User.phone == phone)
        if existing:
            return existing
        raise


async def create_demo_users():
    """Create basic staff users (Admin, Doctor, Receptionist, Photographer)"""
    print("\n=== Creating Staff Users ===")
    
    # Admin
    admin = await _create_or_get_staff(
        phone="07700000001",
        username="admin",
        password="admin123",
        name="System Admin",
        role=Role.ADMIN,
    )
    
    # Doctor
    doctor = await _create_or_get_staff(
        phone="07700000000",
        username="baqer121",
        password="12345",
        name="Dr. Baqer",
        role=Role.DOCTOR,
    )
    
    # Receptionist
    reception = await _create_or_get_staff(
        phone="07700000002",
        username="reception1",
        password="12345",
        name="Receptionist",
        role=Role.RECEPTIONIST,
    )
    
    # Photographer
    photographer = await _create_or_get_staff(
        phone="07700000003",
        username="photographer1",
        password="12345",
        name="Photographer",
        role=Role.PHOTOGRAPHER,
    )
    
    return admin, doctor, reception, photographer


async def create_demo_patients():
    """Create demo patients"""
    print("\n=== Creating Patients ===")
    
    patients_data = [
        {
            "phone": "07701234567",
            "name": "Ahmed Mohammed",
            "gender": "male",
            "age": 35,
            "city": "Baghdad",
        },
        {
            "phone": "07701234568",
            "name": "Fatima Ali",
            "gender": "female",
            "age": 28,
            "city": "Basra",
        },
        {
            "phone": "07701234569",
            "name": "Hassan Karim",
            "gender": "male",
            "age": 42,
            "city": "Baghdad",
        },
        {
            "phone": "07701234570",
            "name": "Zainab Ahmed",
            "gender": "female",
            "age": 25,
            "city": "Mosul",
        },
        {
            "phone": "07701234571",
            "name": "Ali Mahmoud",
            "gender": "male",
            "age": 50,
            "city": "Baghdad",
        },
        {
            "phone": "07701234572",
            "name": "Sara Ibrahim",
            "gender": "female",
            "age": 32,
            "city": "Erbil",
        },
        {
            "phone": "07701234573",
            "name": "Omar Hassan",
            "gender": "male",
            "age": 29,
            "city": "Baghdad",
        },
    ]
    
    patients = []
    for data in patients_data:
        try:
            existing_user = await User.find_one(User.phone == data["phone"])
            if existing_user:
                existing_patient = await Patient.find_one(Patient.user_id == existing_user.id)
                if existing_patient:
                    print(f"[SKIP] Patient {data['name']} already exists ({data['phone']})")
                    patients.append(existing_patient)
                    continue
            patient = await create_patient(**data)
            patients.append(patient)
            print(f"[OK] Created patient: {data['name']} ({data['phone']})")
        except Exception as e:
            print(f"[ERROR] Failed to create patient {data['name']}: {e}")
    
    return patients


async def assign_patients_to_doctor(patients, doctor_user):
    """Assign patients to doctor"""
    print("\n=== Assigning Patients to Doctor ===")
    
    doctor = await Doctor.find_one(Doctor.user_id == doctor_user.id)
    if not doctor:
        print("[ERROR] Doctor profile not found")
        return
    
    doctor_id = str(doctor.id)
    
    for patient in patients:
        try:
            # Only assign if not already assigned to this doctor
            if doctor.id in (patient.doctor_ids or []):
                user = await User.get(patient.user_id)
                print(f"[SKIP] Patient {user.name} already assigned to this doctor")
                continue

            # Replace current doctor list with just this doctor for demo purposes
            await assign_patient_doctors(
                patient_id=str(patient.id),
                doctor_ids=[doctor_id],
                assigned_by_user_id=str(doctor_user.id),
            )
            user = await User.get(patient.user_id)
            print(f"[OK] Assigned patient {user.name} to doctor {doctor_user.name}")
        except Exception as e:
            print(f"[ERROR] Failed to assign patient: {e}")


async def create_demo_appointments(patients, doctor_user):
    """Create demo appointments"""
    print("\n=== Creating Appointments ===")
    
    doctor = await Doctor.find_one(Doctor.user_id == doctor_user.id)
    if not doctor:
        print("[ERROR] Doctor profile not found")
        return
    
    doctor_id = str(doctor.id)
    now = datetime.now(timezone.utc)
    
    # Various appointments (past, today, tomorrow, future)
    appointments_data = [
        {
            "patient": patients[0] if len(patients) > 0 else None,
            "scheduled_at": now - timedelta(days=5, hours=2),
            "note": "Routine checkup - completed successfully",
            "status": "completed",
        },
        {
            "patient": patients[0] if len(patients) > 0 else None,
            "scheduled_at": now + timedelta(days=2, hours=10),
            "note": "Follow-up appointment",
            "status": "scheduled",
        },
        {
            "patient": patients[1] if len(patients) > 1 else None,
            "scheduled_at": now + timedelta(hours=3),
            "note": "Teeth cleaning",
            "status": "scheduled",
        },
        {
            "patient": patients[1] if len(patients) > 1 else None,
            "scheduled_at": now + timedelta(days=1, hours=14),
            "note": "Follow-up visit",
            "status": "scheduled",
        },
        {
            "patient": patients[2] if len(patients) > 2 else None,
            "scheduled_at": now + timedelta(days=7, hours=11),
            "note": "Full examination",
            "status": "scheduled",
        },
        {
            "patient": patients[3] if len(patients) > 3 else None,
            "scheduled_at": now - timedelta(days=2),
            "note": "Root canal treatment - completed",
            "status": "completed",
        },
        {
            "patient": patients[4] if len(patients) > 4 else None,
            "scheduled_at": now + timedelta(days=3, hours=15),
            "note": "Consultation",
            "status": "scheduled",
        },
    ]
    
    for apt_data in appointments_data:
        if not apt_data["patient"]:
            continue
            
        try:
            # Check if appointment already exists
            existing = await Appointment.find_one(
                Appointment.patient_id == apt_data["patient"].id,
                Appointment.doctor_id == doctor.id,
                Appointment.scheduled_at == apt_data["scheduled_at"]
            )
            if existing:
                user = await User.get(apt_data["patient"].user_id)
                print(f"[SKIP] Appointment for {user.name} at {apt_data['scheduled_at']} already exists")
                continue
                
            appointment = await create_appointment(
                patient_id=str(apt_data["patient"].id),
                doctor_id=doctor_id,
                scheduled_at=apt_data["scheduled_at"],
                note=apt_data["note"],
                image_path=None,
            )
            
            appointment.status = apt_data["status"]
            await appointment.save()
            
            user = await User.get(apt_data["patient"].user_id)
            print(f"[OK] Created appointment for {user.name} at {apt_data['scheduled_at']}")
        except Exception as e:
            print(f"[ERROR] Failed to create appointment: {e}")


async def create_demo_treatment_notes(patients, doctor_user):
    """Create demo treatment notes"""
    print("\n=== Creating Treatment Notes ===")
    
    doctor = await Doctor.find_one(Doctor.user_id == doctor_user.id)
    if not doctor:
        print("[ERROR] Doctor profile not found")
        return
    
    doctor_id = str(doctor.id)
    
    notes_data = [
        {
            "patient": patients[0] if len(patients) > 0 else None,
            "note": "Full examination - Teeth in good condition. Recommend regular cleaning every 6 months.",
        },
        {
            "patient": patients[0] if len(patients) > 0 else None,
            "note": "Cavity treatment in upper right molar. Filling completed successfully.",
        },
        {
            "patient": patients[1] if len(patients) > 1 else None,
            "note": "Professional teeth cleaning. Removed tartar and deposits.",
        },
        {
            "patient": patients[2] if len(patients) > 2 else None,
            "note": "Initial examination - Patient needs braces. Explained available options.",
        },
        {
            "patient": patients[3] if len(patients) > 3 else None,
            "note": "Root canal treatment for lower left molar. Completed successfully.",
        },
        {
            "patient": patients[4] if len(patients) > 4 else None,
            "note": "Routine checkup - No issues found. Continue regular oral hygiene.",
        },
    ]
    
    for note_data in notes_data:
        if not note_data["patient"]:
            continue
            
        try:
            note = await create_note(
                patient_id=str(note_data["patient"].id),
                doctor_id=doctor_id,
                note=note_data["note"],
                image_path=None,
            )
            
            user = await User.get(note_data["patient"].user_id)
            print(f"[OK] Created treatment note for {user.name}")
        except Exception as e:
            print(f"[ERROR] Failed to create treatment note: {e}")


async def set_treatment_types(patients, doctor_user):
    """Set treatment types for patients"""
    print("\n=== Setting Treatment Types ===")
    
    if not patients:
        return
    
    doctor = await Doctor.find_one(Doctor.user_id == doctor_user.id)
    if not doctor:
        print("[ERROR] Doctor profile not found")
        return
    
    doctor_id = str(doctor.id)
    treatment_types = [
        "Teeth Cleaning",
        "Root Canal",
        "Braces",
        "Dental Implant",
        "Tooth Filling",
        "Teeth Whitening",
        "Extraction",
    ]
    
    for i, patient in enumerate(patients[:len(treatment_types)]):
        try:
            await set_treatment_type(
                patient_id=str(patient.id),
                doctor_id=doctor_id,
                treatment_type=treatment_types[i],
            )
            user = await User.get(patient.user_id)
            print(f"[OK] Set treatment type '{treatment_types[i]}' for {user.name}")
        except Exception as e:
            print(f"[ERROR] Failed to set treatment type: {e}")


async def main():
    """Main function"""
    print("=" * 50)
    print("Starting Initial Data Seeding")
    print("=" * 50)
    
    settings = get_settings()
    print(f"\nMongoDB URI: {settings.MONGODB_URI}")
    
    await init_db()
    print("[OK] Connected to database\n")
    
    try:
        # 1. Create staff users
        admin, doctor, reception, photographer = await create_demo_users()
        
        # 2. Create patients
        patients = await create_demo_patients()
        
        # 3. Assign patients to doctor
        await assign_patients_to_doctor(patients, doctor)
        
        # 4. Set treatment types
        await set_treatment_types(patients, doctor)
        
        # 5. Create appointments
        await create_demo_appointments(patients, doctor)
        
        # 6. Create treatment notes
        await create_demo_treatment_notes(patients, doctor)
        
        print("\n" + "=" * 50)
        print("[SUCCESS] Initial data seeding completed!")
        print("=" * 50)
        print("\nLogin Credentials:")
        print(f"  Admin: username=admin, password=admin123")
        print(f"  Doctor: username=baqer121, password=12345")
        print(f"  Receptionist: username=reception1, password=12345")
        print(f"  Photographer: username=photographer1, password=12345")
        print(f"\nPatient Phone Numbers (for OTP testing):")
        for i, patient in enumerate(patients[:7], 1):
            user = await User.get(patient.user_id)
            print(f"  {i}. {user.name}: {user.phone}")
        print("\n" + "=" * 50)
        
    except Exception as e:
        print(f"\n[ERROR] An error occurred: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())

