from app.config import get_settings
from motor.motor_asyncio import AsyncIOMotorClient
from beanie import init_beanie

settings = get_settings()

_mongo_client: AsyncIOMotorClient | None = None


async def _ensure_users_phone_unique_index(db) -> None:
    """Drop stale non-unique phone index so Beanie can recreate it as unique."""
    users = db["users"]
    indexes = await users.index_information()
    phone_index = indexes.get("phone_1")
    if phone_index and not phone_index.get("unique"):
        await users.drop_index("phone_1")


async def init_db() -> None:
    """Initialize MongoDB (Beanie) and register document models."""
    global _mongo_client
    _mongo_client = AsyncIOMotorClient(settings.MONGODB_URI)
    # Extract database name from URI, default to 'clinic_db' if not specified
    db_name = settings.MONGODB_URI.rsplit("/", 1)[-1].split("?")[0]  # Remove query params
    if not db_name:
        db_name = "clinic_db"  # Default database name
    await _ensure_users_phone_unique_index(_mongo_client[db_name])
    from app.models import (
        User,
        Doctor,
        Patient,
        Appointment,
        CallCenterAppointment,
        TreatmentNote,
        GalleryImage,
        ChatRoom,
        ChatMessage,
        DeviceToken,
        Notification,
        OTPRequest,
        AssignmentLog,
        InactivePatientLog,
        DoctorWorkingHours,
        ImplantStage,
        DentalChart,  # noqa: F401 — registered below
        ReceptionQueueDay,
        DoctorPresence,  # noqa: F401 — registered below
    )
    await init_beanie(
        database=_mongo_client[db_name],
        document_models=[
            User,
            Doctor,
            Patient,
            Appointment,
        CallCenterAppointment,
            TreatmentNote,
            GalleryImage,
            ChatRoom,
            ChatMessage,
            DeviceToken,
            Notification,
            OTPRequest,
            AssignmentLog,
            InactivePatientLog,
            DoctorWorkingHours,
            ImplantStage,
            DentalChart,
            ReceptionQueueDay,
            DoctorPresence,
        ],
    )
    try:
        from app.services.admin_service import migrate_legacy_patient_profiles

        migrated = await migrate_legacy_patient_profiles()
        if migrated:
            from app.utils.logger import get_logger

            get_logger("database").info(
                "Migrated legacy patient profile fields onto %s patient documents",
                migrated,
            )
    except Exception as exc:
        from app.utils.logger import get_logger

        get_logger("database").warning("Patient profile migration skipped: %s", exc)


async def ping_db() -> bool:
    """Check MongoDB connectivity."""
    if not _mongo_client:
        return False
    try:
        await _mongo_client.admin.command("ping")
        return True
    except Exception:
        return False


# Backward-compatible dependency (unused with Mongo)
async def get_db():
    yield None
