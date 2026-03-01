from app.config import get_settings
from app.utils.logger import get_logger

settings = get_settings()
logger = get_logger("sms")


async def send_sms(phone: str, message: str) -> None:
    """
    Dev implementation:
    - Always log + print OTP/message so يمكنك نسخه بسهولة من الـ Swagger أو من ملف اللوج.
    - لا يتم إرسال SMS حقيقي هنا.
    """
    logger.info(f"[OTP SMS] {phone} => {message}")
    print(f"[OTP] {phone} => {message}")
