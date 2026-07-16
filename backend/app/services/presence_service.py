"""HTTP heartbeat presence for doctors (works when WebSocket/nginx upgrade fails)."""

from datetime import datetime, timedelta, timezone

from beanie import PydanticObjectId as OID

from app.models.presence import DoctorPresence

# Doctor is online if a heartbeat arrived within this window.
ONLINE_TTL = timedelta(seconds=75)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


async def touch_doctor_presence(user_id: str) -> None:
    """Record that the doctor's desktop app is open."""
    oid = OID(user_id)
    now = _utcnow()
    existing = await DoctorPresence.find_one(DoctorPresence.user_id == oid)
    if existing:
        existing.last_seen_at = now
        await existing.save()
        return
    await DoctorPresence(user_id=oid, last_seen_at=now).insert()


async def is_user_online(user_id: str) -> bool:
    """True if doctor has a live socket OR a recent HTTP heartbeat."""
    from app.services.socket_service import is_socket_online

    if is_socket_online(user_id):
        return True

    try:
        oid = OID(user_id)
    except Exception:
        return False

    doc = await DoctorPresence.find_one(DoctorPresence.user_id == oid)
    if not doc or not doc.last_seen_at:
        return False
    return (_utcnow() - _as_utc(doc.last_seen_at)) <= ONLINE_TTL


async def get_online_doctor_user_ids() -> list[str]:
    """Union of socket-online and heartbeat-online doctor user ids."""
    from app.services.socket_service import get_socket_online_doctor_user_ids

    online: set[str] = set(get_socket_online_doctor_user_ids())
    cutoff = _utcnow() - ONLINE_TTL
    docs = await DoctorPresence.find(
        DoctorPresence.last_seen_at >= cutoff
    ).to_list()
    for doc in docs:
        online.add(str(doc.user_id))
    return sorted(online)
