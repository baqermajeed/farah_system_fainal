from typing import Optional
from fastapi import HTTPException
from beanie import PydanticObjectId as OID

from app.models import DeviceToken, Notification
from app.utils.firebase import send_firebase_message

async def register_device_token(*, user_id: str, token: str, platform: Optional[str]) -> DeviceToken:
    """Save or update an FCM device token for the user."""
    existing = await DeviceToken.find_one(DeviceToken.token == token)
    if existing:
        existing.user_id = OID(user_id)
        existing.platform = platform
        await existing.save()
        return existing
    dt = DeviceToken(user_id=OID(user_id), token=token, platform=platform)
    await dt.insert()
    return dt

async def notify_user(*, user_id: str | OID, title: str, body: str) -> None:
    """Send a push notification to all user's devices via Firebase and store record."""
    uid = user_id if isinstance(user_id, OID) else OID(user_id)
    tokens_docs = await DeviceToken.find(DeviceToken.user_id == uid, DeviceToken.active == True).to_list()
    tokens = [dt.token for dt in tokens_docs]
    if tokens:
        await send_firebase_message(tokens, title, body)
    await Notification(user_id=uid, title=title, body=body).insert()
