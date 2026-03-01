from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional, List
from datetime import datetime, timezone, timedelta
from beanie import PydanticObjectId as OID

from app.constants import Role
from app.security import require_roles, get_current_user
from app.schemas import CallCenterAppointmentCreate, CallCenterAppointmentOut, CallCenterAppointmentUpdate
from app.models import CallCenterAppointment, User
from app.services.stats_service import parse_dates


router = APIRouter(
    prefix="/call-center",
    tags=["call-center"],
    dependencies=[Depends(require_roles([Role.CALL_CENTER, Role.ADMIN]))],
)


@router.post("/appointments", response_model=CallCenterAppointmentOut)
async def create_call_center_appointment(
    payload: CallCenterAppointmentCreate,
    current=Depends(get_current_user),
):
    """إضافة موعد حضور أولي بواسطة موظف مركز الاتصالات."""
    try:
        scheduled_at = datetime.fromisoformat(payload.scheduled_at.replace("Z", "+00:00"))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid scheduled_at format")

    created_by_username = current.username or current.phone

    doc = CallCenterAppointment(
        patient_name=payload.patient_name,
        patient_phone=payload.patient_phone,
        scheduled_at=scheduled_at,
        governorate=payload.governorate or "",
        platform=payload.platform or "",
        note=payload.note or "",
        created_by_user_id=current.id,
        created_by_username=created_by_username,
    )
    await doc.insert()

    return CallCenterAppointmentOut(
        id=str(doc.id),
        patient_name=doc.patient_name,
        patient_phone=doc.patient_phone,
        scheduled_at=doc.scheduled_at.isoformat(),
        governorate=doc.governorate,
        platform=doc.platform,
        note=doc.note,
        created_by_user_id=str(doc.created_by_user_id),
        created_by_username=doc.created_by_username,
        created_at=doc.created_at.isoformat(),
        status=getattr(doc, "status", "pending") or "pending",
        accepted_at=doc.accepted_at.isoformat() if getattr(doc, "accepted_at", None) else None,
    )


@router.put("/appointments/{appointment_id}", response_model=CallCenterAppointmentOut)
async def update_call_center_appointment(
    appointment_id: str,
    payload: CallCenterAppointmentUpdate,
    current=Depends(get_current_user),
):
    """تعديل موعد مركز الاتصالات."""
    try:
        oid = OID(appointment_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid appointment id")
    doc = await CallCenterAppointment.get(oid)
    if not doc:
        raise HTTPException(status_code=404, detail="الموعد غير موجود")
    if payload.patient_name is not None:
        doc.patient_name = payload.patient_name
    if payload.patient_phone is not None:
        doc.patient_phone = payload.patient_phone
    if payload.scheduled_at is not None:
        try:
            doc.scheduled_at = datetime.fromisoformat(payload.scheduled_at.replace("Z", "+00:00"))
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid scheduled_at format")
    if payload.governorate is not None:
        doc.governorate = payload.governorate
    if payload.platform is not None:
        doc.platform = payload.platform
    if payload.note is not None:
        doc.note = payload.note
    doc.updated_at = datetime.now(timezone.utc)
    await doc.save()
    return CallCenterAppointmentOut(
        id=str(doc.id),
        patient_name=doc.patient_name,
        patient_phone=doc.patient_phone,
        scheduled_at=doc.scheduled_at.isoformat(),
        governorate=doc.governorate,
        platform=doc.platform,
        note=doc.note,
        created_by_user_id=str(doc.created_by_user_id),
        created_by_username=doc.created_by_username,
        created_at=doc.created_at.isoformat(),
        status=getattr(doc, "status", "pending") or "pending",
        accepted_at=doc.accepted_at.isoformat() if getattr(doc, "accepted_at", None) else None,
    )


@router.delete("/appointments/{appointment_id}")
async def delete_call_center_appointment(
    appointment_id: str,
    current=Depends(get_current_user),
):
    """حذف موعد مركز الاتصالات."""
    try:
        oid = OID(appointment_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid appointment id")
    doc = await CallCenterAppointment.get(oid)
    if not doc:
        raise HTTPException(status_code=404, detail="الموعد غير موجود")
    await doc.delete()
    return {"ok": True}


@router.get("/appointments", response_model=List[CallCenterAppointmentOut])
async def list_call_center_appointments(
    date_from: Optional[str] = Query(None, description="فلترة حسب تاريخ الموعد من (ISO)"),
    date_to: Optional[str] = Query(None, description="فلترة حسب تاريخ الموعد إلى (ISO)"),
    created_by_user_id: Optional[str] = Query(None, description="فلترة حسب موظف محدد (للأدمن فقط)"),
    search: Optional[str] = Query(None, description="بحث بالاسم أو الهاتف أو يوزر الموظف"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current=Depends(get_current_user),
):
    """عرض جدول مواعيد مركز الاتصالات. موظف مركز الاتصالات يرى مواعيده فقط، والأدمن يرى الكل أو يفلتر حسب موظف."""
    df, dt = parse_dates(date_from, date_to)
    query = CallCenterAppointment.find()

    # موظف مركز الاتصالات: مواعيده فقط. الأدمن: الكل أو حسب created_by_user_id
    if current.role == Role.CALL_CENTER:
        query = query.find(CallCenterAppointment.created_by_user_id == current.id)
    elif created_by_user_id:
        try:
            uid = OID(created_by_user_id)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid created_by_user_id")
        query = query.find(CallCenterAppointment.created_by_user_id == uid)

    if df:
        query = query.find(CallCenterAppointment.scheduled_at >= df)
    if dt:
        query = query.find(CallCenterAppointment.scheduled_at < dt)

    if search and search.strip():
        s = search.strip()
        query = query.find(
            {
                "$or": [
                    {"patient_name": {"$regex": s, "$options": "i"}},
                    {"patient_phone": {"$regex": s, "$options": "i"}},
                    {"created_by_username": {"$regex": s, "$options": "i"}},
                ]
            }
        )

    items = await query.sort("-created_at").skip(skip).limit(limit).to_list()

    return [
        CallCenterAppointmentOut(
            id=str(i.id),
            patient_name=i.patient_name,
            patient_phone=i.patient_phone,
            scheduled_at=i.scheduled_at.isoformat(),
            governorate=getattr(i, "governorate", "") or "",
            platform=getattr(i, "platform", "") or "",
            note=getattr(i, "note", "") or "",
            created_by_user_id=str(i.created_by_user_id),
            created_by_username=i.created_by_username,
            created_at=i.created_at.isoformat(),
            status=getattr(i, "status", "pending") or "pending",
            accepted_at=i.accepted_at.isoformat() if getattr(i, "accepted_at", None) else None,
        )
        for i in items
    ]


@router.get("/appointments/stats")
async def call_center_appointments_stats(
    date_from: Optional[str] = Query(None, description="فلترة حسب تاريخ الإنشاء من (ISO)"),
    date_to: Optional[str] = Query(None, description="فلترة حسب تاريخ الإنشاء إلى (ISO)"),
    user_id: Optional[str] = Query(None, description="فلترة لموظف محدد (للأدمن فقط)"),
    current=Depends(get_current_user),
):
    """عداد مواعيد الموظف (اليوم/الشهر/من-إلى) حسب تاريخ إنشاء الموعد."""
    if current.role == Role.CALL_CENTER:
        uid = current.id
    else:
        uid = None
        if user_id:
            try:
                uid = OID(user_id)
            except Exception:
                raise HTTPException(status_code=400, detail="Invalid user_id")

    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    tomorrow_start = today_start + timedelta(days=1)

    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if month_start.month == 12:
        next_month_start = month_start.replace(year=month_start.year + 1, month=1)
    else:
        next_month_start = month_start.replace(month=month_start.month + 1)

    base = CallCenterAppointment.find()
    if uid:
        base = base.find(CallCenterAppointment.created_by_user_id == uid)

    today = await base.find(
        CallCenterAppointment.created_at >= today_start,
        CallCenterAppointment.created_at < tomorrow_start,
    ).count()

    this_month = await base.find(
        CallCenterAppointment.created_at >= month_start,
        CallCenterAppointment.created_at < next_month_start,
    ).count()

    df, dt = parse_dates(date_from, date_to)
    range_query = base
    if df:
        range_query = range_query.find(CallCenterAppointment.created_at >= df)
    if dt:
        range_query = range_query.find(CallCenterAppointment.created_at < dt)
    range_count = await range_query.count()

    accepted = 0
    if uid:
        creator = await User.get(uid)
        if creator:
            accepted = getattr(creator, "call_center_accepted_count", 0) or 0

    return {
        "user_id": str(uid) if uid else None,
        "today": today,
        "this_month": this_month,
        "range": {"from": date_from, "to": date_to, "count": range_count},
        "accepted": accepted,
    }
