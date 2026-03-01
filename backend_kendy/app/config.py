from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import List
import os


class Settings(BaseSettings):
    """Global app settings loaded from environment.
    - Keep defaults light for dev.
    - Override via .env or real env vars.
    """

    APP_NAME: str = "clinic_api"
    APP_ENV: str = "dev"
    APP_DEBUG: bool = True

    MONGODB_URI: str = "mongodb://localhost:27017/"

    # JWT settings — يجب أن يكون نفس القيمة في backend (فرح) ليقبل الكندي توكن موظف الـ call center.
    # على السيرفر: في .env ضع JWT_SECRET=farah_sys_final_project (كلمة project كاملة بحرف t في الآخر).
    JWT_SECRET: str = "farah_sys_final_project"

    # عند قبول موعد من الاستقبال في الكندي، إذا كان منشئ الموعد من النجف نرسل النقطة لـ backend فرح.
    FARAH_API_BASE_URL: str = "https://sys-api.farahdent.com"
    FARAH_INTERNAL_SECRET: str | None = None
    JWT_ALGORITHM: str = "HS256"
    # مدة صلاحية الـ Access Token (قصير المدى - 1 ساعة)
    # Access Token قصير لأسباب أمنية، يتم تجديده تلقائياً باستخدام Refresh Token
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60  # 1 ساعة
    # مدة صلاحية الـ Refresh Token (طويل المدى - 30 يوم)
    # Refresh Token يستخدم لتجديد Access Token تلقائياً
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30  # 30 يوم

    # Raw CORS string from env (comma-separated); parsed via cors_origins property
    CORS_ORIGINS: str | None = None

    # Cloudflare R2 storage config
    R2_ACCOUNT_ID: str | None = None
    R2_ACCESS_KEY_ID: str | None = None
    R2_SECRET_ACCESS_KEY: str | None = None
    R2_BUCKET_NAME: str | None = None
    # Public base URL, e.g. https://cdn.example.com or https://<account>.r2.cloudflarestorage.com/<bucket>
    R2_PUBLIC_BASE: str | None = None

    # SMS provider config (dummy | twilio)
    SMS_PROVIDER: str = "dummy"
    TWILIO_ACCOUNT_SID: str | None = None
    TWILIO_AUTH_TOKEN: str | None = None
    TWILIO_FROM_NUMBER: str | None = None

    # OTPIQ OTP provider
    OTPIQ_API_KEY: str | None = None
    OTPIQ_BASE_URL: str | None = None
    OTP_TTL_SECONDS: int = 120

    # Firebase Admin SDK service account
    FIREBASE_CREDENTIALS_FILE: str | None = None

    class Config:
        env_file = ".env"
        case_sensitive = False

    @property
    def cors_origins(self) -> List[str]:
        """Return CORS origins as a list, parsing comma-separated env string."""
        raw = self.CORS_ORIGINS or os.getenv("CORS_ORIGINS", "") or ""
        return [o.strip() for o in raw.split(",") if o.strip()]


@lru_cache()
def get_settings() -> Settings:
    """Cached settings instance."""
    return Settings()