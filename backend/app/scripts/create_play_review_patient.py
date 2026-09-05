"""
Create Google Play review demo patient account.
Run: python -m app.scripts.create_play_review_patient
"""
import asyncio
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

from app.config import get_settings
from app.database import init_db
from app.models import User
from app.services.admin_service import create_patient


async def main() -> None:
    settings = get_settings()
    phone = settings.PLAY_REVIEW_DEMO_PHONE
    await init_db()

    existing = await User.find_one(User.phone == phone)
    if existing:
        print(f"[SKIP] Play review patient already exists: {phone} ({existing.name})")
        return

    patient = await create_patient(
        phone=phone,
        name="Google Play Reviewer",
        gender="male",
        age=30,
        city="Baghdad",
    )
    print(f"[OK] Created Play review patient: {phone} (patient_id={patient.id})")


if __name__ == "__main__":
    asyncio.run(main())
