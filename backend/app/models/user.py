from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime, timezone
from app.constants import Role


class User(Document):
    """مستخدم النظام (مريض/طبيب/مدير/استقبال/مصور).

    ملاحظة:
    - المرضى يستخدمون تسجيل الدخول عبر OTP فقط (حسب رقم الجوال).
    - الأطباء/الاستقبال/المصور/المدير يسجلون الدخول عن طريق username + password.
    """

    # بيانات أساسية مشتركة
    name: str | None = None
    phone: Indexed(str, unique=True)  # فريد للجميع
    role: Role
    gender: str | None = None  # "male" | "female"
    age: int | None = None
    city: str | None = None
    imageUrl: str | None = None  # رابط صورة الملف الشخصي

    # بيانات خاصة بتسجيل الدخول للطاقم (اختيارية للمرضى)
    username: Indexed(str, unique=True) | None = None
    password_hash: str | None = None

    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "users"
