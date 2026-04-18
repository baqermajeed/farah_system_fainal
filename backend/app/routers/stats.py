from fastapi import APIRouter, Depends, Query
from typing import Optional

from app.security import require_roles, get_current_user
from app.constants import Role
from app.services.stats_service import (
    get_overview_stats,
    get_users_stats,
    get_appointments_stats,
    get_doctors_stats,
    get_chat_stats,
    get_notifications_stats,
    get_transfers_stats,
    get_dashboard_stats,
    get_doctor_profile_stats,
    get_doctor_patient_transfer_stats,
)

router = APIRouter(prefix="/stats", tags=["statistics"])


@router.get("/dashboard")
async def dashboard_stats(current=Depends(require_roles([Role.ADMIN, Role.DOCTOR]))):
    """إحصائيات Dashboard شاملة - ملخص سريع لكل شيء في التطبيق."""
    return await get_dashboard_stats()


@router.get("/overview")
async def overview_stats(
    group: str = Query("day", description="نوع التجميع: day, month, year"),
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(require_roles([Role.ADMIN, Role.DOCTOR])),
):
    """ملخص عام شامل: مرضى جدد، مواعيد، سجلات، صور، محادثات، إشعارات مجمعة حسب الفترة."""
    return await get_overview_stats(group=group, date_from=date_from, date_to=date_to)


@router.get("/users")
async def users_stats(current=Depends(require_roles([Role.ADMIN]))):
    """إحصائيات المستخدمين حسب الدور."""
    return await get_users_stats()


@router.get("/appointments")
async def appointments_stats(
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(require_roles([Role.ADMIN, Role.DOCTOR])),
):
    """إحصائيات المواعيد الشاملة: حسب الحالة، حسب الطبيب، قادمة/ماضية."""
    return await get_appointments_stats(date_from=date_from, date_to=date_to)


@router.get("/doctors")
async def doctors_stats(current=Depends(require_roles([Role.ADMIN]))):
    """إحصائيات الأطباء: عدد المرضى، المواعيد، السجلات لكل طبيب."""
    return await get_doctors_stats()


@router.get("/doctors/{doctor_id}/profile")
async def doctor_profile_stats(
    doctor_id: str,
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(require_roles([Role.ADMIN])),
):
    """بروفايل الطبيب للمدير: مرضى/مواعيد/رسائل اليوم + تحويلات اليوم/الشهر/ضمن فترة."""
    return await get_doctor_profile_stats(doctor_id=doctor_id, date_from=date_from, date_to=date_to)


@router.get("/chat")
async def chat_stats(
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(require_roles([Role.ADMIN, Role.DOCTOR])),
):
    """إحصائيات المحادثات: عدد الغرف، الرسائل، حسب الطبيب."""
    return await get_chat_stats(date_from=date_from, date_to=date_to)


@router.get("/notifications")
async def notifications_stats(
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(require_roles([Role.ADMIN])),
):
    """إحصائيات الإشعارات: عدد الإشعارات المرسلة، الأجهزة النشطة."""
    return await get_notifications_stats(date_from=date_from, date_to=date_to)


@router.get("/transfers")
async def transfers_stats(
    group: str = Query("day", description="نوع التجميع: day, month, year"),
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    doctor_id: Optional[str] = Query(None, description="فلترة التحويلات لطبيب محدد (Doctor ID)"),
    current=Depends(require_roles([Role.ADMIN])),
):
    """إحصائيات تحويلات المرضى بين الأطباء."""
    return await get_transfers_stats(group=group, date_from=date_from, date_to=date_to, doctor_id=doctor_id)


@router.get("/doctors/{doctor_id}/patient-transfers")
async def doctor_patient_transfer_stats(
    doctor_id: str,
    date_from: Optional[str] = Query(None, description="تاريخ البداية (ISO format)"),
    date_to: Optional[str] = Query(None, description="تاريخ النهاية (ISO format)"),
    current=Depends(require_roles([Role.ADMIN, Role.DOCTOR])),
):
    """
    إحصائيات المرضى المحولين لهذا الطبيب:
    - عدد المرضى المحولين خلال اليوم/الشهر/فترة محددة
    - عدد المرضى النشطين خلال اليوم/الشهر/فترة محددة
    - عدد المرضى غير النشطين (حتى لو تم حذفهم من حسابه) خلال اليوم/الشهر/فترة محددة
    
    ملاحظة: هذه الإحصائيات تشمل حتى المرضى الذين تم حذفهم من حساب الطبيب لاحقاً
    (غير النشطين)، لأننا نبحث في جميع المرضى الذين لديهم سجل في doctor_profiles.
    """
    return await get_doctor_patient_transfer_stats(
        doctor_id=doctor_id,
        date_from=date_from,
        date_to=date_to,
    )

