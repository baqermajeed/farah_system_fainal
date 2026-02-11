from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Dict, Literal

from app.constants import Role

# -------------------- Auth / User Schemas --------------------


class UserBase(BaseModel):
    name: Optional[str] = None
    phone: str
    gender: Optional[str] = Field(None, description="male|female")
    age: Optional[int] = None
    city: Optional[str] = None
    imageUrl: Optional[str] = None


class UserOut(UserBase):
    id: str
    role: Role
    doctor_manager: Optional[bool] = None  # يظهر فقط للطبيب (True/False)

    class Config:
        from_attributes = True


class OTPRequestIn(BaseModel):
    phone: str


class OTPVerifyIn(UserBase):
    """Verify OTP؛ إنشاء مستخدم جديد دائمًا كمريض عند عدم وجوده."""

    code: str


class StaffLoginIn(BaseModel):
    """Body بديل (في حال احتجته) لتسجيل دخول الطاقم؛ حاليًا نستخدم OAuth2PasswordRequestForm."""

    username: str
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

# -------------------- Patient Schemas --------------------

class PatientCreate(BaseModel):
    name: Optional[str] = None
    phone: str
    gender: Optional[str] = None
    age: Optional[int] = None
    city: Optional[str] = None
    visit_type: Optional[str] = None  # "مريض جديد" | "مراجع قديم" (اختياري)
    consultation_type: Optional[str] = None  # "معاينة مدفوعة" | "معاينة مجانية" (اختياري)
    # يمكن ملؤها لاحقاً من الطبيب، لكنها متاحة هنا للتوسّع مستقبلاً
    payment_methods: Optional[List[str]] = None


class DoctorPatientProfileOut(BaseModel):
    treatment_type: Optional[str] = None
    assigned_at: Optional[datetime] = None
    last_action_at: Optional[datetime] = None
    payment_methods: Optional[List[str]] = None

    class Config:
        from_attributes = True

class PatientOut(BaseModel):
    id: str
    user_id: str
    name: Optional[str]
    phone: str
    gender: Optional[str] = None
    age: Optional[int] = None
    city: Optional[str] = None
    treatment_type: Optional[str] = None
    visit_type: Optional[str] = None
    consultation_type: Optional[str] = None
    payment_methods: Optional[List[str]] = None
    # Mongo ObjectId تُرجع كنصوص في الـ API
    doctor_ids: List[str] = []  # قائمة معرفات الأطباء المرتبطين
    doctor_profiles: Dict[str, DoctorPatientProfileOut] = Field(default_factory=dict)
    qr_code_data: str
    qr_image_path: Optional[str] = None
    imageUrl: Optional[str] = None
    created_at: Optional[str] = None

    class Config:
        from_attributes = True

class PatientUpdate(BaseModel):
    name: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[int] = None
    city: Optional[str] = None
    treatment_type: Optional[str] = None
    phone: Optional[str] = None  # Admin only
    visit_type: Optional[str] = None
    consultation_type: Optional[str] = None
    payment_methods: Optional[List[str]] = None


class PatientTransferIn(BaseModel):
    """طلب تحويل مريض من طبيب مدير إلى طبيب آخر."""
    target_doctor_id: str
    mode: Literal["shared", "move"] = "shared"  # shared: يبقى عند الاثنين، move: ينحذف من عند المحوّل

# -------------------- Doctor Schemas --------------------

class DoctorOut(BaseModel):
    id: str
    user_id: str
    name: Optional[str] = None
    phone: str
    imageUrl: Optional[str] = None

    class Config:
        from_attributes = True

# -------------------- Working Hours --------------------

class WorkingHoursIn(BaseModel):
    """Input schema for working hours."""
    day_of_week: int = Field(..., ge=0, le=6, description="Day of week (0=Sunday, 6=Saturday)")
    start_time: str = Field(..., pattern=r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$', description="Start time in HH:MM format")
    end_time: str = Field(..., pattern=r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$', description="End time in HH:MM format")
    is_working: bool = Field(default=True, description="Whether the doctor works on this day")
    slot_duration: int = Field(default=30, ge=15, le=120, description="Slot duration in minutes (must be multiple of 15)")


class WorkingHoursOut(BaseModel):
    """Output schema for working hours."""
    id: str
    doctor_id: str
    day_of_week: int
    start_time: str
    end_time: str
    is_working: bool
    slot_duration: int
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True


# -------------------- Call Center Appointments --------------------

class CallCenterAppointmentCreate(BaseModel):
    patient_name: str
    patient_phone: str
    scheduled_at: str  # ISO datetime

    @field_validator("scheduled_at")
    @classmethod
    def must_include_time(cls, v: str) -> str:
        """يجب أن يحتوي التاريخ على وقت (ساعة:دقيقة). أمثلة مقبولة: 2025-11-01T14:30 أو 2025-11-01 14:30"""
        if not isinstance(v, str):
            raise ValueError("scheduled_at must be ISO string with time")
        sep = "T" if "T" in v else (" " if " " in v else None)
        if sep:
            time_part = v.split(sep, 1)[1]
            if ":" in time_part:
                return v
        raise ValueError("scheduled_at يجب أن يتضمن التاريخ والوقت مثل 2025-11-01T14:30")


class CallCenterAppointmentOut(BaseModel):
    id: str
    patient_name: str
    patient_phone: str
    scheduled_at: str
    created_by_user_id: str
    created_by_username: str
    created_at: str

    class Config:
        from_attributes = True


# -------------------- Appointments --------------------

class AppointmentCreate(BaseModel):
    patient_id: str
    scheduled_at: str  # ISO datetime
    note: Optional[str] = None

    @field_validator("scheduled_at")
    @classmethod
    def must_include_time(cls, v: str) -> str:
        """يجب أن يحتوي التاريخ على وقت (ساعة:دقيقة). أمثلة مقبولة: 2025-11-01T14:30 أو 2025-11-01 14:30"""
        if not isinstance(v, str):
            raise ValueError("scheduled_at must be ISO string with time")
        sep = "T" if "T" in v else (" " if " " in v else None)
        if sep:
            time_part = v.split(sep, 1)[1]
            if ":" in time_part:
                return v
        raise ValueError("scheduled_at يجب أن يتضمن التاريخ والوقت مثل 2025-11-01T14:30")

class AppointmentStatusUpdate(BaseModel):
    """Schema لتحديث حالة الموعد."""
    status: str = Field(..., description="الحالة الجديدة: pending, completed, cancelled, late")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        allowed_statuses = ["pending", "completed", "cancelled", "late"]
        if v.lower() not in allowed_statuses:
            raise ValueError(f"Status must be one of: {', '.join(allowed_statuses)}")
        return v.lower()

class AppointmentDateTimeUpdate(BaseModel):
    """Schema لتعديل تاريخ ووقت الموعد."""
    scheduled_at: str  # ISO datetime string

    @field_validator("scheduled_at")
    @classmethod
    def must_include_time(cls, v: str) -> str:
        """يجب أن يحتوي التاريخ على وقت (ساعة:دقيقة)."""
        if not isinstance(v, str):
            raise ValueError("scheduled_at must be ISO string with time")
        sep = "T" if "T" in v else (" " if " " in v else None)
        if sep:
            time_part = v.split(sep, 1)[1]
            if ":" in time_part:
                return v
        raise ValueError("scheduled_at يجب أن يتضمن التاريخ والوقت مثل 2025-11-01T14:30")

class AppointmentOut(BaseModel):
    id: str
    patient_id: str
    patient_name: Optional[str] = None
    patient_phone: Optional[str] = None  # ⭐ إضافة رقم الهاتف
    doctor_id: str
    doctor_name: Optional[str] = None
    scheduled_at: str
    note: Optional[str] = None
    image_path: Optional[str] = None  # للتوافق مع البيانات القديمة
    image_paths: List[str] = []  # قائمة الصور الجديدة
    status: str

    class Config:
        from_attributes = True

class PatientAppointmentsOut(BaseModel):
    primary: List[AppointmentOut] = []
    secondary: List[AppointmentOut] = []


# -------------------- Reception: Appointments Overview --------------------

class ReceptionAppointmentOut(BaseModel):
    """موعد واحد كما يظهر لموظف الاستقبال مع معلومات المريض والطبيب."""

    id: str
    patient_id: str
    patient_name: Optional[str] = None
    patient_phone: Optional[str] = None
    doctor_id: str
    doctor_name: Optional[str] = None
    scheduled_at: str
    note: Optional[str] = None
    image_path: Optional[str] = None
    status: str

# -------------------- Notes / Gallery --------------------

class NoteCreate(BaseModel):
    patient_id: str
    note: Optional[str] = None

class NoteOut(BaseModel):
    id: str
    patient_id: str
    doctor_id: str
    note: Optional[str]
    image_path: Optional[str]
    image_paths: Optional[List[str]] = None
    created_at: str

    class Config:
        from_attributes = True

class NoteUpdate(BaseModel):
    note: Optional[str] = None

class GalleryCreate(BaseModel):
    patient_id: str
    note: Optional[str] = None

class GalleryOut(BaseModel):
    id: str
    patient_id: str
    image_path: str
    note: Optional[str] = None
    created_at: str

    class Config:
        from_attributes = True

# -------------------- Notifications --------------------

class DeviceTokenIn(BaseModel):
    token: str
    platform: Optional[str] = None

# -------------------- Chat --------------------

class ChatMessageIn(BaseModel):
    """Schema لإرسال رسالة جديدة."""
    content: Optional[str] = None
    imageUrl: Optional[str] = None

class ChatMessageOut(BaseModel):
    id: str
    room_id: str
    sender_user_id: str | None
    sender_role: Optional[str] = None
    content: str
    imageUrl: Optional[str] = None
    is_read: bool = False
    created_at: str

    class Config:
        from_attributes = True

class ChatMessageIn(BaseModel):
    content: Optional[str] = None
    imageUrl: Optional[str] = None

class ChatListItemOut(BaseModel):
    """Schema for chat list item with last message and unread count."""
    patient_id: str
    patient_name: str
    patient_image_url: Optional[str] = None
    last_message: Optional[str] = None
    last_message_time: Optional[str] = None
    unread_count: int = 0
    room_id: str

    class Config:
        from_attributes = True

# -------------------- QR --------------------

class QRScanOut(BaseModel):
    patient: PatientOut | None
    doctors: List[DoctorOut] = []  # قائمة الأطباء المرتبطين بالمريض

# -------------------- Implant Stages --------------------

class ImplantStageOut(BaseModel):
    """Schema لعرض مرحلة زراعة."""
    id: str
    patient_id: str
    stage_name: str
    scheduled_at: str
    is_completed: bool
    appointment_id: str | None = None
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True

class ImplantStageDateUpdate(BaseModel):
    """Schema لتحديث تاريخ مرحلة."""
    scheduled_at: str  # ISO datetime string

class ImplantStagesResponse(BaseModel):
    """Schema لاستجابة قائمة المراحل."""
    stages: List[ImplantStageOut]
