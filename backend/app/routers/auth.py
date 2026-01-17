from fastapi import APIRouter, Depends, Request, Body, UploadFile, File
from fastapi.security import OAuth2PasswordRequestForm
from datetime import datetime, timezone

from app.rate_limit import limiter
from app.schemas import OTPRequestIn, OTPVerifyIn, Token, UserOut, StaffLoginIn, PatientCreate
from app.models.user import User
from app.security import get_current_user
from app.services.auth_service import (
    request_otp,
    verify_otp_and_login,
    staff_login_with_password,
)
from app.services.admin_service import create_patient
from app.security import create_access_token
from fastapi import HTTPException
from app.utils.r2_clinic import upload_clinic_image

router = APIRouter(prefix="/auth", tags=["auth"])

@router.get("/test")
async def test_auth_endpoint():
    """Test endpoint to verify auth router is working"""
    print("✅ [AUTH ROUTER] Test endpoint called - router is working!")
    return {"message": "Auth router is working", "status": "ok"}


@router.post("/request-otp")
@limiter.limit("5/minute")
async def route_request_otp(request: Request, payload: OTPRequestIn):
    """طلب إرسال رمز تحقق (OTP) إلى رقم الهاتف المدخل (للمرضى فقط).
    Rate limit: 5 requests per minute per IP.
    """
    print("=" * 60)
    print("🔐 [AUTH ROUTER] /auth/request-otp endpoint called")
    print(f"   📱 Phone: {payload.phone}")
    print(f"   🌐 Client IP: {request.client.host if request.client else 'unknown'}")
    
    try:
        print("   ⏳ Calling request_otp...")
        await request_otp(payload.phone)
        print("   ✅ OTP requested successfully")
        print("=" * 60)
        return {"status": "sent"}
    except Exception as e:
        print(f"   ❌ OTP request failed: {e}")
        print(f"   🔴 Error type: {type(e).__name__}")
        import traceback
        print(f"   📋 Traceback: {traceback.format_exc()}")
        print("=" * 60)
        raise


@router.post("/verify-otp")
@limiter.limit("10/minute")
async def route_verify_otp(request: Request, payload: OTPVerifyIn):
    """التحقق من رمز OTP فقط - لا ينشئ حساب جديد.
    يرجع {account_exists: true/false, token: ...} أو {account_exists: false}
    Rate limit: 10 requests per minute per IP.
    """
    print("=" * 60)
    print("🔐 [AUTH ROUTER] /auth/verify-otp endpoint called")
    print(f"   📱 Phone: {payload.phone}")
    print(f"   🔑 Code: {payload.code}")
    
    try:
        print("   ⏳ Calling verify_otp_and_login...")
        token, user = await verify_otp_and_login(
            phone=payload.phone,
            code=payload.code,
        )
        
        if token is None or user is None:
            print("   ⚠️ OTP verified but account does not exist")
            print("=" * 60)
            return {"account_exists": False}
        
        print("   ✅ OTP verified successfully")
        print(f"   👤 User: {user.name} ({user.role.value})")
        print(f"   🆔 User ID: {user.id}")
        print("=" * 60)
        return {"account_exists": True, "token": token}
    except Exception as e:
        print(f"   ❌ OTP verification failed: {e}")
        print(f"   🔴 Error type: {type(e).__name__}")
        import traceback
        print(f"   📋 Traceback: {traceback.format_exc()}")
        print("=" * 60)
        raise


@router.post("/create-patient-account", response_model=Token)
@limiter.limit("5/minute")
async def route_create_patient_account(request: Request, payload: PatientCreate):
    """إنشاء حساب مريض جديد بعد التحقق من OTP.
    يجب التحقق من OTP أولاً قبل استدعاء هذا الـ endpoint.
    Rate limit: 5 requests per minute per IP.
    """
    print("=" * 60)
    print("🔐 [AUTH ROUTER] /auth/create-patient-account endpoint called")
    print(f"   📱 Phone: {payload.phone}")
    print(f"   👤 Name: {payload.name}")
    print(f"   🚻 Gender: {payload.gender}")
    print(f"   📅 Age: {payload.age}")
    print(f"   🏙️ City: {payload.city}")
    
    try:
        # التحقق من أن رقم الهاتف غير مستخدم
        from app.models import User
        existing_user = await User.find_one(User.phone == payload.phone)
        if existing_user:
            print(f"   ❌ Phone already exists")
            raise HTTPException(status_code=400, detail="Phone already exists")
        
        print("   ⏳ Creating patient account...")
        # إنشاء حساب المريض
        patient = await create_patient(
            phone=payload.phone,
            name=payload.name,
            gender=payload.gender,
            age=payload.age,
            city=payload.city,
        )
        
        # جلب User المرتبط
        user = await User.get(patient.user_id)
        
        print("   ✅ Patient account created successfully")
        print(f"   👤 User: {user.name} ({user.role.value})")
        print(f"   🆔 User ID: {user.id}")
        
        # إنشاء token
        token = create_access_token(
            {
                "sub": str(user.id),
                "role": user.role,
                "phone": user.phone,
            }
        )
        print("=" * 60)
        return Token(access_token=token)
    except HTTPException:
        raise
    except Exception as e:
        print(f"   ❌ Account creation failed: {e}")
        print(f"   🔴 Error type: {type(e).__name__}")
        import traceback
        print(f"   📋 Traceback: {traceback.format_exc()}")
        print("=" * 60)
        raise HTTPException(status_code=500, detail=f"Failed to create account: {str(e)}")


@router.post("/staff-login", response_model=Token)
async def route_staff_login(form_data: OAuth2PasswordRequestForm = Depends()):
    """تسجيل دخول الطبيب/الموظف/المصور/المدير باستخدام username/password."""
    print("=" * 60)
    print("🔐 [AUTH ROUTER] /auth/staff-login endpoint called")
    print(f"   👤 Username: {form_data.username}")
    print(f"   🔑 Password: {'*' * len(form_data.password)}")
    print(f"   📝 Form data keys: {form_data.__dict__.keys()}")
    
    try:
        print("   ⏳ Calling staff_login_with_password...")
        token, user = await staff_login_with_password(
            username=form_data.username,
            password=form_data.password,
        )
        print("   ✅ Login successful")
        print(f"   👤 User: {user.name} ({user.role.value})")
        print(f"   🆔 User ID: {user.id}")
        print(f"   🎫 Token generated: {token[:30]}...")
        print("=" * 60)
        return Token(access_token=token)
    except Exception as e:
        print(f"   ❌ Login failed: {e}")
        print(f"   🔴 Error type: {type(e).__name__}")
        import traceback
        print(f"   📋 Traceback: {traceback.format_exc()}")
        print("=" * 60)
        raise


@router.get("/me", response_model=UserOut)
async def route_me(current: User = Depends(get_current_user)):
    """معلومات المستخدم الحالي حسب التوكن.

    نعيد UserOut بشكل صريح مع تحويل ObjectId إلى str لتجنّب
    ResponseValidationError من FastAPI/Pydantic.
    """
    return UserOut(
        id=str(current.id),
        name=current.name,
        phone=current.phone,
        gender=current.gender,
        age=current.age,
        city=current.city,
        role=current.role,
        imageUrl=current.imageUrl,
    )


@router.put("/me", response_model=UserOut)
async def route_update_me(
    name: str = Body(None),
    phone: str = Body(None),
    current: User = Depends(get_current_user),
):
    """تحديث معلومات المستخدم الحالي."""
    if name is not None:
        current.name = name
    if phone is not None:
        # التحقق من أن رقم الهاتف غير مستخدم من قبل مستخدم آخر
        existing_user = await User.find_one(User.phone == phone)
        if existing_user and existing_user.id != current.id:
            raise HTTPException(
                status_code=400, detail="رقم الهاتف مستخدم من قبل"
            )
        current.phone = phone
    
    current.updated_at = datetime.now(timezone.utc)
    await current.save()
    
    return UserOut(
        id=str(current.id),
        name=current.name,
        phone=current.phone,
        gender=current.gender,
        age=current.age,
        city=current.city,
        role=current.role,
        imageUrl=current.imageUrl,
    )


@router.post("/me/upload-image", response_model=UserOut)
async def route_upload_profile_image(
    image: UploadFile = File(...),
    current: User = Depends(get_current_user),
):
    """رفع صورة الملف الشخصي للمستخدم."""
    IMAGE_TYPES = ("image/jpeg", "image/png", "image/webp")
    
    if image.content_type not in IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"نوع الملف غير مدعوم. الأنواع المدعومة: {', '.join(IMAGE_TYPES)}",
        )
    
    file_bytes = await image.read()
    
    # رفع الصورة باستخدام user_id بدلاً من patient_id
    image_path = await upload_clinic_image(
        patient_id=str(current.id),  # استخدام user_id كمعرف
        folder="profile",
        file_bytes=file_bytes,
        content_type=image.content_type,
    )
    
    # تحديث imageUrl في User
    # upload_clinic_image now returns a direct /media/... URL
    
    current.imageUrl = image_path
    current.updated_at = datetime.now(timezone.utc)
    await current.save()
    
    return UserOut(
        id=str(current.id),
        name=current.name,
        phone=current.phone,
        gender=current.gender,
        age=current.age,
        city=current.city,
        role=current.role,
        imageUrl=current.imageUrl,
    )