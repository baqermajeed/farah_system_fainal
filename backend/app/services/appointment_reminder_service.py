"""
خدمة تذكير المواعيد - ترسل إشعارات push للمرضى قبل مواعيدهم.
"""
from datetime import datetime, timezone, timedelta
from typing import List
from beanie import PydanticObjectId as OID

from app.models import Appointment, Patient, User
from app.services.notification_service import notify_user
from app.utils.logger import get_logger

logger = get_logger("appointment_reminder")


async def check_and_send_reminders():
    """
    فحص المواعيد القادمة وإرسال إشعارات التذكير في الأوقات المناسبة.
    يتم استدعاء هذه الوظيفة بشكل دوري (كل ساعة في الساعة 9 صباحاً).
    """
    try:
        now = datetime.now(timezone.utc)
        
        # نرسل الإشعارات فقط في الساعة 9 صباحاً (بين 9:00 و 9:59)
        if now.hour != 9:
            return
        
        today_9am = now.replace(hour=9, minute=0, second=0, microsecond=0)
        
        # نفحص المواعيد في نطاق 4 أيام (اليوم + 3 أيام قادمة)
        # نبدأ من اليوم في الساعة 9 صباحاً
        start_date = today_9am
        end_date = today_9am + timedelta(days=4)
        
        # جلب جميع المواعيد المجدولة في المستقبل
        upcoming_appointments = await Appointment.find(
            Appointment.scheduled_at >= start_date,
            Appointment.scheduled_at <= end_date,
            Appointment.status == "scheduled"
        ).to_list()
        
        logger.info(f"🔍 Checking {len(upcoming_appointments)} upcoming appointments for reminders at 9 AM")
        
        sent_count = 0
        for appointment in upcoming_appointments:
            try:
                # فحص إشعار قبل 3 أيام
                if await _should_send_3d_reminder(appointment, today_9am):
                    await _send_3d_reminder(appointment)
                    sent_count += 1
                
                # فحص إشعار قبل يوم واحد
                if await _should_send_1d_reminder(appointment, today_9am):
                    await _send_1d_reminder(appointment)
                    sent_count += 1
                
                # فحص إشعار في نفس اليوم
                if await _should_send_day_reminder(appointment, today_9am):
                    await _send_day_reminder(appointment)
                    sent_count += 1
                    
            except Exception as e:
                logger.error(f"❌ Error processing appointment {appointment.id}: {e}")
                continue
        
        if sent_count > 0:
            logger.info(f"✅ Sent {sent_count} reminder notification(s)")
        else:
            logger.info("ℹ️ No reminders to send at this time")
            
    except Exception as e:
        logger.error(f"❌ Error in check_and_send_reminders: {e}")


async def _should_send_3d_reminder(appointment: Appointment, today_9am: datetime) -> bool:
    """تحقق إذا كان يجب إرسال إشعار قبل 3 أيام."""
    if appointment.remind_3d_sent:
        return False
    
    # الموعد بعد 3 أيام بالضبط (في الساعة 9 صباحاً)
    target_date = appointment.scheduled_at.date()
    reminder_date = target_date - timedelta(days=3)
    today_date = today_9am.date()
    
    return reminder_date == today_date


async def _should_send_1d_reminder(appointment: Appointment, today_9am: datetime) -> bool:
    """تحقق إذا كان يجب إرسال إشعار قبل يوم واحد."""
    if appointment.remind_1d_sent:
        return False
    
    # الموعد بعد يوم واحد بالضبط (في الساعة 9 صباحاً)
    target_date = appointment.scheduled_at.date()
    reminder_date = target_date - timedelta(days=1)
    today_date = today_9am.date()
    
    return reminder_date == today_date


async def _should_send_day_reminder(appointment: Appointment, today_9am: datetime) -> bool:
    """تحقق إذا كان يجب إرسال إشعار في نفس اليوم."""
    if appointment.remind_day_sent:
        return False
    
    # الموعد في نفس اليوم (في الساعة 9 صباحاً)
    target_date = appointment.scheduled_at.date()
    today_date = today_9am.date()
    
    return target_date == today_date


async def _send_3d_reminder(appointment: Appointment):
    """إرسال إشعار قبل 3 أيام."""
    try:
        patient = await Patient.get(appointment.patient_id)
        if not patient:
            logger.warning(f"⚠️ Patient not found for appointment {appointment.id}")
            return
        
        await notify_user(
            user_id=patient.user_id,
            title="تذكير موعد",
            body="لديك موعد بعد 3 أيام"
        )
        
        appointment.remind_3d_sent = True
        await appointment.save()
        
        logger.info(f"✅ Sent 3-day reminder for appointment {appointment.id}")
    except Exception as e:
        logger.error(f"❌ Error sending 3-day reminder: {e}")


async def _send_1d_reminder(appointment: Appointment):
    """إرسال إشعار قبل يوم واحد."""
    try:
        patient = await Patient.get(appointment.patient_id)
        if not patient:
            logger.warning(f"⚠️ Patient not found for appointment {appointment.id}")
            return
        
        await notify_user(
            user_id=patient.user_id,
            title="تذكير موعد",
            body="لديك موعد غداً"
        )
        
        appointment.remind_1d_sent = True
        await appointment.save()
        
        logger.info(f"✅ Sent 1-day reminder for appointment {appointment.id}")
    except Exception as e:
        logger.error(f"❌ Error sending 1-day reminder: {e}")


async def _send_day_reminder(appointment: Appointment):
    """إرسال إشعار في نفس اليوم."""
    try:
        patient = await Patient.get(appointment.patient_id)
        if not patient:
            logger.warning(f"⚠️ Patient not found for appointment {appointment.id}")
            return
        
        # تنسيق وقت الموعد
        appointment_time = appointment.scheduled_at.strftime("%I:%M %p")
        
        await notify_user(
            user_id=patient.user_id,
            title="تذكير موعد",
            body=f"لديك موعد اليوم في الساعة {appointment_time}"
        )
        
        appointment.remind_day_sent = True
        await appointment.save()
        
        logger.info(f"✅ Sent same-day reminder for appointment {appointment.id}")
    except Exception as e:
        logger.error(f"❌ Error sending same-day reminder: {e}")

