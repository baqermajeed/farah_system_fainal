from fastapi import HTTPException

from app.constants import Role
from app.models import User
from app.security import create_access_token, create_refresh_token, verify_password
from app.services.otp_service import (
    create_otp_request,
    normalize_iraqi_phone,
    verify_otp_or_raise,
)
from app.services.otpiq import OTPIQError, send_verification_otp

async def request_otp(phone: str) -> None:
    """إنشاء وإرسال رمز OTP للهاتف (يحفظ آخر طلب)."""
    code, otp = await create_otp_request(phone=phone)
    # OTPIQ expects phoneNumber WITHOUT '+'
    try:
        await send_verification_otp(phone_number=otp.phone, verification_code=code)
    except OTPIQError as e:
        raise HTTPException(status_code=502, detail="Failed to send OTP") from e


async def verify_otp_and_login(
    *,
    phone: str,
    code: str,
) -> tuple[tuple[str, str] | None, User | None]:
    """Verify OTP فقط - لا ينشئ حساب جديد. يرجع ((access_token, refresh_token), user) أو (None, None) إذا لم يكن الحساب موجود."""
    # Validate OTP (expiry + attempts) and mark verified on success
    await verify_otp_or_raise(phone=phone, code=code)

    normalized = normalize_iraqi_phone(phone)
    variants = {phone.strip(), normalized}
    # Also try legacy 07xxxxxxxxx if user data stored that way
    if normalized.startswith("9647") and len(normalized) > 3:
        variants.add("0" + normalized[3:])

    user = await User.find_one({"phone": {"$in": list(variants)}})

    # إن وجد مستخدم وليس مريضًا فلا نسمح باستخدام OTP له
    if user and user.role != Role.PATIENT:
        raise HTTPException(
            status_code=400,
            detail="OTP login is allowed for patients only",
        )

    if not user:
        return None, None

    # إنشاء access_token و refresh_token
    token_data = {
        "sub": str(user.id),
        "role": user.role,
        "phone": user.phone,
    }
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    
    return (access_token, refresh_token), user


# ---------------- Staff login (username/password) ----------------


async def staff_login_with_password(*, username: str, password: str) -> tuple[tuple[str, str], User]:
    """تسجيل دخول الطبيب/الاستقبال/المصور/المدير عن طريق username + password.
    يرجع ((access_token, refresh_token), user).
    """
    print(f"🔍 [AuthService] staff_login_with_password called")
    print(f"   👤 Searching for user with username: {username}")
    
    user = await User.find_one(User.username == username)
    
    if not user:
        print(f"   ❌ User not found with username: {username}")
        raise HTTPException(status_code=400, detail="Invalid credentials")
    
    print(f"   ✅ User found: {user.name} (ID: {user.id}, Role: {user.role.value})")
    print(f"   🔍 Checking role...")
    
    if user.role not in {
        Role.ADMIN,
        Role.DOCTOR,
        Role.RECEPTIONIST,
        Role.PHOTOGRAPHER,
        Role.CALL_CENTER,
    }:
        print(f"   ❌ Invalid role for staff login: {user.role.value}")
        # لا يسمح للمرضى باستخدام هذا النوع من تسجيل الدخول
        raise HTTPException(status_code=400, detail="Invalid credentials")
    
    print(f"   ✅ Role is valid for staff login")
    print(f"   🔍 Verifying password...")
    
    password_valid = verify_password(password, user.password_hash)
    print(f"   🔐 Password verification result: {password_valid}")
    
    if not password_valid:
        print(f"   ❌ Password verification failed")
        raise HTTPException(status_code=400, detail="Invalid credentials")
    
    print(f"   ✅ Password verified successfully")
    print(f"   🎫 Creating access token and refresh token...")
    
    # إنشاء access_token و refresh_token
    token_data = {
        "sub": str(user.id),
        "role": user.role,
        "phone": user.phone,
        "username": user.username,
    }
    access_token = create_access_token(token_data)
    refresh_token = create_refresh_token(token_data)
    print(f"   ✅ Tokens created successfully")
    return (access_token, refresh_token), user


async def refresh_access_token(refresh_token: str) -> tuple[str, str]:
    """تجديد Access Token باستخدام Refresh Token.
    يرجع (new_access_token, new_refresh_token).
    """
    from app.security import decode_token, create_access_token, create_refresh_token
    from app.models.user import User
    
    print(f"🔄 [AuthService] refresh_access_token called")
    
    try:
        # فك تشفير refresh_token والتحقق من نوعه
        payload = decode_token(refresh_token, token_type="refresh")
        user_id: str | None = payload.get("sub")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid refresh token")
        
        # التحقق من وجود المستخدم
        user = await User.get(user_id)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        
        # إنشاء tokens جديدة
        token_data = {
            "sub": str(user.id),
            "role": user.role,
            "phone": user.phone,
        }
        if user.username:
            token_data["username"] = user.username
        
        new_access_token = create_access_token(token_data)
        new_refresh_token = create_refresh_token(token_data)
        
        print(f"   ✅ Tokens refreshed successfully for user: {user.name}")
        return new_access_token, new_refresh_token
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"   ❌ Token refresh failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
