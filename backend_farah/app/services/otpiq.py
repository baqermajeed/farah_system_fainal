import httpx

from app.config import get_settings


class OTPIQError(RuntimeError):
    pass


async def send_verification_otp(*, phone_number: str, verification_code: str) -> None:
    """
    Send OTP via OTPIQ.
    - phone_number must be normalized and WITHOUT '+'.
    """
    settings = get_settings()
    if not settings.OTPIQ_API_KEY or not settings.OTPIQ_BASE_URL:
        raise OTPIQError("OTPIQ configuration is missing (OTPIQ_API_KEY/OTPIQ_BASE_URL)")

    base_url = settings.OTPIQ_BASE_URL.rstrip("/")
    url = f"{base_url}/sms"

    headers = {
        "Authorization": f"Bearer {settings.OTPIQ_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "phoneNumber": phone_number,
        "smsType": "verification",
        "verificationCode": verification_code,
        "provider": "sms",
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.post(url, headers=headers, json=payload)
        if resp.status_code >= 400:
            raise OTPIQError(f"OTPIQ error {resp.status_code}: {resp.text}")

