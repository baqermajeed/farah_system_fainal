from fastapi import APIRouter, Depends

from app.schemas import DeviceTokenIn
from app.security import get_current_user
from app.services.notification_service import register_device_token

router = APIRouter(prefix="/notifications", tags=["notifications"])

@router.post("/register", status_code=204)
async def register_token(payload: DeviceTokenIn, current=Depends(get_current_user)):
    """تسجيل رمز جهاز FCM لإشعارات الدفع."""
    await register_device_token(user_id=str(current.id), token=payload.token, platform=payload.platform)
    return None
