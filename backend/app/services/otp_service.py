import re
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from passlib.context import CryptContext

from app.config import get_settings
from app.models.otp import OTPRequest


_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
_MAX_ATTEMPTS = 5


def normalize_iraqi_phone(phone: str) -> str:
    """
    Normalize Iraqi phone numbers:
    - remove spaces and dashes
    - if starts with '+', remove '+'
    - if starts with '07', convert to '9647...'
    """
    raw = (phone or "").strip()
    raw = re.sub(r"[\s\-]+", "", raw)
    if raw.startswith("+"):
        raw = raw[1:]
    if raw.startswith("07"):
        raw = "964" + raw[1:]  # 07xxxxxxxxx -> 9647xxxxxxxxx
    return raw


def generate_otp_code() -> str:
    # 6-digit numeric
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_otp(code: str) -> str:
    return _pwd_context.hash(code)


def verify_hashed_otp(code: str, code_hash: str) -> bool:
    return _pwd_context.verify(code, code_hash)


async def create_otp_request(*, phone: str) -> tuple[str, OTPRequest]:
    """
    Generate + store OTP request and return (code, otp_doc).
    """
    settings = get_settings()
    ttl_seconds = settings.OTP_TTL_SECONDS or 120

    normalized = normalize_iraqi_phone(phone)
    if not normalized:
        raise HTTPException(status_code=400, detail="Invalid phone")

    code = generate_otp_code()
    now = datetime.now(timezone.utc)
    expires = now + timedelta(seconds=ttl_seconds)

    otp = OTPRequest(
        phone=normalized,
        code_hash=hash_otp(code),
        expires_at=expires,
        attempts=0,
        verified_at=None,
    )
    await otp.insert()
    return code, otp


async def verify_otp_or_raise(*, phone: str, code: str) -> OTPRequest:
    """
    Verify OTP:
    - checks latest unverified OTP for phone
    - checks expiry
    - checks attempts max 5
    - increments attempts on failure
    - marks verified_at on success
    """
    normalized = normalize_iraqi_phone(phone)
    if not normalized:
        raise HTTPException(status_code=400, detail="Invalid phone")

    now = datetime.now(timezone.utc)
    otp = (
        await OTPRequest.find(
            OTPRequest.phone == normalized,
            OTPRequest.verified_at == None,  # noqa: E711
        )
        .sort(-OTPRequest.created_at)
        .first_or_none()
    )
    if not otp:
        raise HTTPException(status_code=400, detail="OTP not found")

    expires_at = otp.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if otp.attempts >= _MAX_ATTEMPTS:
        raise HTTPException(status_code=400, detail="Too many attempts")

    if expires_at < now:
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    if not verify_hashed_otp(code.strip(), otp.code_hash):
        otp.attempts = int(otp.attempts or 0) + 1
        await otp.save()
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    otp.verified_at = now
    await otp.save()
    return otp

