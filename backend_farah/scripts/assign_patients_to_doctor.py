"""
Script لربط المرضى الموجودين بالطبيب
يضيف primary_doctor_id للمرضى الذين ليس لديهم طبيب
"""
import asyncio
import sys
import os
from pathlib import Path

# Fix encoding for Windows console
if sys.platform == 'win32':
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# إضافة مسار المشروع إلى Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.database import init_db
from app.models import Patient, Doctor, User
from beanie import PydanticObjectId as OID


async def assign_patients_to_doctor(force: bool = False):
    """ربط جميع المرضى بالطبيب الأول المتاح
    
    Args:
        force: إذا كان True، يعيد ربط جميع المرضى (حتى المربوطين)
    """
    await init_db()
    
    print("🔍 البحث عن الأطباء...")
    doctors = await Doctor.find({}).to_list()
    
    if not doctors:
        print("❌ لا يوجد أطباء في قاعدة البيانات!")
        print("   💡 يرجى إنشاء طبيب أولاً")
        return
    
    print(f"✅ تم العثور على {len(doctors)} طبيب(ين)")
    
    # استخدام الطبيب الأول
    doctor = doctors[0]
    doctor_user = await User.get(doctor.user_id)
    print(f"👨‍⚕️ استخدام الطبيب: {doctor_user.name if doctor_user else 'Unknown'} (ID: {doctor.id})")
    
    print("\n🔍 البحث عن المرضى...")
    all_patients = await Patient.find({}).to_list()
    print(f"✅ تم العثور على {len(all_patients)} مريض(ين) في قاعدة البيانات")
    
    # تصفية المرضى الذين ليس لديهم طبيب
    if force:
        patients_to_assign = all_patients
        print(f"\n⚠️ وضع الإجبار: سيعاد ربط جميع المرضى")
    else:
        patients_to_assign = [
            p for p in all_patients 
            if p.primary_doctor_id is None and p.secondary_doctor_id is None
        ]
        print(f"\n📋 المرضى غير المربوطين: {len(patients_to_assign)}")
    
    if not patients_to_assign:
        print("✅ جميع المرضى مربوطون بأطباء!")
        return
    
    # ربط المرضى بالطبيب
    print(f"\n🔗 ربط {len(patients_to_assign)} مريض بالطبيب...")
    assigned_count = 0
    
    for patient in patients_to_assign:
        try:
            old_primary = patient.primary_doctor_id
            patient.primary_doctor_id = doctor.id
            await patient.save()
            assigned_count += 1
            
            # جلب معلومات المريض
            user = await User.get(patient.user_id)
            patient_name = user.name if user else "Unknown"
            status = "إعادة ربط" if old_primary else "ربط جديد"
            print(f"   ✅ {status}: {patient_name} (ID: {patient.id})")
        except Exception as e:
            print(f"   ❌ خطأ في ربط المريض {patient.id}: {e}")
    
    print(f"\n✅ تم ربط {assigned_count} مريض(ين) بنجاح!")
    print(f"   الطبيب: {doctor_user.name if doctor_user else 'Unknown'}")
    print(f"   ID الطبيب: {doctor.id}")


async def assign_specific_patient_to_doctor(patient_id: str, doctor_id: str, as_primary: bool = True):
    """ربط مريض محدد بطبيب محدد"""
    await init_db()
    
    try:
        patient = await Patient.get(OID(patient_id))
        if not patient:
            print(f"❌ المريض غير موجود: {patient_id}")
            return
        
        doctor = await Doctor.get(OID(doctor_id))
        if not doctor:
            print(f"❌ الطبيب غير موجود: {doctor_id}")
            return
        
        if as_primary:
            patient.primary_doctor_id = doctor.id
        else:
            patient.secondary_doctor_id = doctor.id
        
        await patient.save()
        
        user = await User.get(patient.user_id)
        doctor_user = await User.get(doctor.user_id)
        
        print(f"✅ تم ربط المريض '{user.name if user else 'Unknown'}' بالطبيب '{doctor_user.name if doctor_user else 'Unknown'}'")
        print(f"   نوع الربط: {'أساسي' if as_primary else 'ثانوي'}")
        
    except Exception as e:
        print(f"❌ خطأ: {e}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="ربط المرضى بالأطباء")
    parser.add_argument(
        "--patient-id",
        help="ID المريض المحدد (اختياري)",
        default=None
    )
    parser.add_argument(
        "--doctor-id",
        help="ID الطبيب المحدد (اختياري)",
        default=None
    )
    parser.add_argument(
        "--secondary",
        action="store_true",
        help="ربط كطبيب ثانوي (بدلاً من أساسي)",
        default=False
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="إعادة ربط جميع المرضى (حتى المربوطين)",
        default=False
    )
    
    args = parser.parse_args()
    
    if args.patient_id and args.doctor_id:
        # ربط مريض محدد بطبيب محدد
        asyncio.run(assign_specific_patient_to_doctor(
            args.patient_id,
            args.doctor_id,
            as_primary=not args.secondary
        ))
    else:
        # ربط جميع المرضى بالطبيب الأول
        asyncio.run(assign_patients_to_doctor(force=args.force))

