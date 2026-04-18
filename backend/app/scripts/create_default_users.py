import asyncio

from app.config import get_settings
from app.database import init_db
from app.constants import Role
from app.models import User
from app.services.admin_service import create_staff_user


async def _create_or_get_staff(*, phone: str, username: str, password: str, name: str, role: Role) -> User:
    """
    Create a staff user (admin / doctor) if it doesn't already exist.
    Returns the existing user if found.
    """
    existing = await User.find_one(User.username == username)
    if existing:
        print(f"[SKIP] User '{username}' already exists with id={existing.id}")
        return existing

    user = await create_staff_user(
        phone=phone,
        username=username,
        password=password,
        name=name,
        role=role,
    )
    print(f"[OK] Created {role.value} user '{username}' with id={user.id}")
    return user


async def main() -> None:
    """
    One-time script to create:
      - Admin user
      - Doctor user
      - Receptionist user

    Default credentials (يمكنك تعديلها هنا قبل التشغيل):
      - Admin:
          username: admin
          password: admin123
          phone: 07700000001
      - Doctor (staff login):
          username: baqer121
          password: 12345
          phone: 07700000000
      - Receptionist (staff login):
          username: reception1
          password: 12345
          phone: 07700000002
    """
    settings = get_settings()
    print(f"Using MongoDB URI: {settings.MONGODB_URI}")

    # Initialize Beanie/Mongo connection
    await init_db()

    # Create Admin
    await _create_or_get_staff(
        phone="07700000001",
        username="admin",
        password="admin123",
        name="System Admin",
        role=Role.ADMIN,
    )

    # Create Doctor (as requested)
    await _create_or_get_staff(
        phone="07700000000",
        username="baqer121",
        password="12345",
        name="د. باقر",
        role=Role.DOCTOR,
    )

    # Create Receptionist
    await _create_or_get_staff(
        phone="07700000002",
        username="reception1",
        password="12345",
        name="موظف استقبال",
        role=Role.RECEPTIONIST,
    )

    print("Done.")


if __name__ == "__main__":
    asyncio.run(main())


