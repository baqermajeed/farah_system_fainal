"""استدعاءات داخلية لمركز الاتصالات (مثلاً من backend الكندي لزيادة عداد المقبولة لموظف النجف)."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from beanie import PydanticObjectId as OID

from app.models import User
from app.security import verify_internal_secret


router = APIRouter(
    prefix="/call-center",
    tags=["call-center-internal"],
    dependencies=[Depends(verify_internal_secret)],
)


class IncrementAcceptedBody(BaseModel):
    user_id: str


@router.post("/internal/increment-accepted-count")
async def increment_call_center_accepted_count(body: IncrementAcceptedBody):
    """زيادة عداد المواعيد المقبولة لموظف مركز اتصالات (في عيادة النجف).
    يُستدعى من backend الكندي عندما يقبل موظف الاستقبال هناك موعداً أضافه موظف النجف.
    """
    try:
        oid = OID(body.user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user_id")

    user = await User.get(oid)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    current = getattr(user, "call_center_accepted_count", 0) or 0
    user.call_center_accepted_count = current + 1
    await user.save()
    return {"ok": True, "user_id": body.user_id, "new_count": user.call_center_accepted_count}
