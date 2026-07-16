from fastapi import APIRouter, Depends, HTTPException, status

from app.constants import Role
from app.models.user import User
from app.security import get_current_user
from app.services import presence_service

router = APIRouter(prefix="/presence", tags=["presence"])


@router.post("/heartbeat")
async def presence_heartbeat(current: User = Depends(get_current_user)):
    """Doctor desktop app pings this while open — marks them online."""
    if current.role != Role.DOCTOR:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="الأطباء فقط",
        )
    await presence_service.touch_doctor_presence(str(current.id))
    return {"ok": True, "is_online": True}


@router.get("/online-doctors")
async def list_online_doctors(current: User = Depends(get_current_user)):
    """Online doctor user_ids for reception / doctor managers."""
    if current.role not in (Role.DOCTOR, Role.RECEPTIONIST):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="غير مصرح",
        )
    ids = await presence_service.get_online_doctor_user_ids()
    return {"online_user_ids": ids}
