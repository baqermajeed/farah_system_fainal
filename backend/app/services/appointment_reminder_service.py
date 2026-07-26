"""
خدمة تذكير المواعيد — إشعارات تلقائية للمريض:
- قبل الموعد بيوم واحد (9:00 صباحاً بتوقيت العراق)
- في يوم الموعد (9:00 صباحاً بتوقيت العراق)
"""
from __future__ import annotations

from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

from beanie import PydanticObjectId as OID

from app.models import Appointment, Patient, User, Doctor
from app.services.notification_service import notify_user
from app.utils.patient_out import resolve_patient_name
from app.utils.logger import get_logger

logger = get_logger("appointment_reminder")

IRAQ_TZ = ZoneInfo("Asia/Baghdad")
REMINDER_HOUR = 9  # 9:00 صباحاً بتوقيت بغداد


def reset_appointment_reminder_flags(appointment: Appointment) -> None:
    """إعادة ضبط علامات التذكير بعد تعديل وقت الموعد."""
    appointment.remind_1d_sent = False
    appointment.remind_day_sent = False
    appointment.remind_3d_sent = False


def _to_iraq(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(IRAQ_TZ)


def _iraq_now() -> datetime:
    return datetime.now(IRAQ_TZ)


def _format_when(dt: datetime) -> str:
    local = _to_iraq(dt)
    return local.strftime("%d-%m-%Y الساعة %I:%M %p")


async def check_and_send_reminders() -> None:
    """
    يُستدعى كل ساعة عبر APScheduler.
    الإرسال الفعلي يتم فقط الساعة 9:00 صباحاً بتوقيت العراق.
    """
    try:
        now_iraq = _iraq_now()
        if now_iraq.hour != REMINDER_HOUR:
            return

        today = now_iraq.date()
        tomorrow = today + timedelta(days=1)

        # مواعيد اليوم وغداً (مع هامش للتحويل الزمني)
        window_start = datetime.combine(
            today - timedelta(days=1),
            datetime.min.time(),
            tzinfo=IRAQ_TZ,
        ).astimezone(timezone.utc)
        window_end = datetime.combine(
            tomorrow + timedelta(days=1),
            datetime.max.time(),
            tzinfo=IRAQ_TZ,
        ).astimezone(timezone.utc)

        upcoming = await Appointment.find(
            Appointment.scheduled_at >= window_start,
            Appointment.scheduled_at <= window_end,
            Appointment.status == "pending",
        ).to_list()

        logger.info(
            "Checking %s pending appointments for reminders (Iraq date=%s)",
            len(upcoming),
            today.isoformat(),
        )

        sent_count = 0
        for appointment in upcoming:
            try:
                appt_local = _to_iraq(appointment.scheduled_at)
                appt_date = appt_local.date()

                if appt_date == tomorrow and not appointment.remind_1d_sent:
                    if await _send_1d_reminder(appointment):
                        sent_count += 1

                if appt_date == today and not appointment.remind_day_sent:
                    if await _send_day_reminder(appointment):
                        sent_count += 1
            except Exception as exc:
                logger.error("Error processing appointment %s: %s", appointment.id, exc)

        if sent_count:
            logger.info("Sent %s appointment reminder(s)", sent_count)
        else:
            logger.info("No appointment reminders to send at this time")
    except Exception as exc:
        logger.error("Error in check_and_send_reminders: %s", exc)


async def _doctor_display_name(doctor_id: OID | str) -> str | None:
    try:
        doctor = await Doctor.get(OID(str(doctor_id)))
        if not doctor or not doctor.user_id:
            return None
        user = await User.get(doctor.user_id)
        if user and user.name:
            name = user.name.strip()
            return name if name.startswith("د.") else f"د. {name}"
    except Exception:
        pass
    return None


async def _build_reminder_body(
    *,
    patient: Patient,
    when_label: str,
    scheduled_at: datetime,
    doctor_id: OID | str,
) -> str:
    user = await User.get(patient.user_id)
    patient_name = resolve_patient_name(patient, user)
    when = _format_when(scheduled_at)
    doctor_name = await _doctor_display_name(doctor_id)

    if patient_name and doctor_name:
        return f"تذكير: موعد {patient_name} {when_label} ({when}) مع {doctor_name}"
    if doctor_name:
        return f"تذكير: لديك موعد {when_label} ({when}) مع {doctor_name}"
    if patient_name:
        return f"تذكير: موعد {patient_name} {when_label} ({when})"
    return f"تذكير: لديك موعد {when_label} ({when})"


async def _send_1d_reminder(appointment: Appointment) -> bool:
    """إشعار قبل الموعد بيوم واحد."""
    try:
        patient = await Patient.get(appointment.patient_id)
        if not patient:
            logger.warning("Patient not found for appointment %s", appointment.id)
            return False

        body = await _build_reminder_body(
            patient=patient,
            when_label="غداً",
            scheduled_at=appointment.scheduled_at,
            doctor_id=appointment.doctor_id,
        )

        await notify_user(
            user_id=patient.user_id,
            title="تذكير موعد غداً",
            body=body,
            type="appointment_reminder",
            patient_id=str(patient.id),
            data={
                "appointmentId": str(appointment.id),
                "reminder": "1d",
                "patientId": str(patient.id),
                "doctorId": str(appointment.doctor_id),
            },
        )

        appointment.remind_1d_sent = True
        await appointment.save()
        logger.info("Sent 1-day reminder for appointment %s", appointment.id)
        return True
    except Exception as exc:
        logger.error("Error sending 1-day reminder: %s", exc)
        return False


async def _send_day_reminder(appointment: Appointment) -> bool:
    """إشعار في يوم الموعد."""
    try:
        patient = await Patient.get(appointment.patient_id)
        if not patient:
            logger.warning("Patient not found for appointment %s", appointment.id)
            return False

        body = await _build_reminder_body(
            patient=patient,
            when_label="اليوم",
            scheduled_at=appointment.scheduled_at,
            doctor_id=appointment.doctor_id,
        )

        await notify_user(
            user_id=patient.user_id,
            title="تذكير موعد اليوم",
            body=body,
            type="appointment_reminder",
            patient_id=str(patient.id),
            data={
                "appointmentId": str(appointment.id),
                "reminder": "day",
                "patientId": str(patient.id),
                "doctorId": str(appointment.doctor_id),
            },
        )

        appointment.remind_day_sent = True
        await appointment.save()
        logger.info("Sent same-day reminder for appointment %s", appointment.id)
        return True
    except Exception as exc:
        logger.error("Error sending same-day reminder: %s", exc)
        return False
