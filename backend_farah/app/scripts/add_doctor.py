"""
Script to add a new doctor to the database
"""
import asyncio
import sys

# Fix encoding for Windows console
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

from app.config import get_settings
from app.database import init_db
from app.constants import Role
from app.services.admin_service import create_staff_user


async def add_doctor():
    """Add a new doctor to the database"""
    print("=" * 50)
    print("Adding New Doctor")
    print("=" * 50)
    
    settings = get_settings()
    print(f"\nMongoDB URI: {settings.MONGODB_URI}")
    
    await init_db()
    print("[OK] Connected to database\n")
    
    try:
        # بيانات الطبيب الجديد
        phone = "07700000005"
        username = "doctor2"
        password = "12345"
        name = "Dr. Second Doctor"
        
        # التحقق من وجود المستخدم مسبقاً
        from app.models import User
        existing_user = await User.find_one(User.username == username)
        if existing_user:
            print(f"[SKIP] المستخدم '{username}' موجود بالفعل")
            print(f"  Name: {existing_user.name}")
            print(f"  Phone: {existing_user.phone}")
            print(f"  Role: {existing_user.role.value}")
            return
        
        existing_phone = await User.find_one(User.phone == phone)
        if existing_phone:
            print(f"[SKIP] رقم الهاتف '{phone}' مستخدم بالفعل")
            return
        
        print(f"\nإنشاء حساب الطبيب...")
        print(f"  Phone: {phone}")
        print(f"  Username: {username}")
        print(f"  Name: {name}")
        
        user = await create_staff_user(
            phone=phone,
            username=username,
            password=password,
            name=name,
            role=Role.DOCTOR,
        )
        
        print("\n" + "=" * 50)
        print("[SUCCESS] تم إنشاء حساب الطبيب بنجاح!")
        print("=" * 50)
        print(f"\nمعلومات الطبيب:")
        print(f"  ID: {user.id}")
        print(f"  Name: {user.name or 'N/A'}")
        print(f"  Phone: {user.phone}")
        print(f"  Username: {user.username}")
        print(f"  Role: {user.role.value}")
        print(f"\nيمكن للطبيب تسجيل الدخول باستخدام:")
        print(f"  Username: {user.username}")
        print(f"  Password: {password}")
        print("\n" + "=" * 50)
        
    except Exception as e:
        print(f"\n[ERROR] حدث خطأ: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(add_doctor())

