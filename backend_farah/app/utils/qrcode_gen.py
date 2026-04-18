import os
from io import BytesIO

import qrcode
from fastapi import HTTPException

from app.models import Patient
from app.utils.r2_clinic import upload_clinic_image
from app.utils.logger import get_logger

logger = get_logger("qrcode")


async def ensure_patient_qr(patient: Patient) -> None:
    """توليد وحفظ QR للمريض إن لم يكن موجودًا ثم رفعه إلى R2 وتخزين URL.

    في حال فشل الرفع إلى R2 (مثلاً مشكلة SSL محلية)، لا نمنع إنشاء المريض:
    - نطبع الخطأ في اللوج
    - نترك qr_image_path = None، لكن qr_code_data يكون موجود ويمكن استخدامه.
    """
    if not patient.qr_code_data:
        salt = os.urandom(4).hex()
        # استخدم جزء من معرف المريض لتمييز الكود
        pid = str(patient.id)[-6:]
        patient.qr_code_data = f"P{pid}-{salt}"

    img = qrcode.make(patient.qr_code_data)
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    file_bytes = buffer.getvalue()

    try:
        url = await upload_clinic_image(
            patient_id=str(patient.id),
            folder="qr",
            file_bytes=file_bytes,
            content_type="image/png",
        )
        patient.qr_image_path = url
    except Exception as e:
        # لا نرمي استثناء حتى لا نفشل إنشاء المريض؛ فقط نسجل الخطأ
        logger.error(f"Failed to upload QR image to R2 for patient {patient.id}: {e}")
        patient.qr_image_path = None

    await patient.save()

async def get_patient_by_qr(code: str) -> Patient | None:
    """جلب مريض عبر قيمة qr_code_data."""
    return await Patient.find_one(Patient.qr_code_data == code)
