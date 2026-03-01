from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from datetime import datetime, timezone
from beanie import PydanticObjectId as OID
from typing import Optional

from app.security import get_current_user
from app.schemas import ChatMessageOut, ChatMessageIn, ChatListItemOut
from app.models import ChatRoom, ChatMessage, Patient, User, Doctor
from app.constants import Role
from app.utils.chat_helpers import ensure_chat_room_user_ids
from app.utils.r2_clinic import upload_clinic_image
from app.utils.logger import get_logger

logger = get_logger("chat_router")

router = APIRouter(prefix="/chat", tags=["chat"]) 

async def _get_or_room_for_user(*, patient_id: str, user: User, doctor_id: str | None = None) -> ChatRoom:
    """الحصول على أو إنشاء غرفة محادثة بين الطبيب والمريض."""
    try:
        patient = await Patient.get(OID(patient_id))
    except Exception:
        patient = None

    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    selected_doctor: Doctor | None = None

    if user.role == Role.DOCTOR:
        selected_doctor = await Doctor.find_one(Doctor.user_id == user.id)
        if not selected_doctor:
            raise HTTPException(status_code=403, detail="Doctor profile not found")
        if selected_doctor.id not in patient.doctor_ids:
            raise HTTPException(status_code=403, detail="Doctor not assigned to this patient")

    elif user.role == Role.PATIENT:
        if patient.user_id != user.id:
            raise HTTPException(status_code=403, detail="Forbidden")
        if not patient.doctor_ids:
            raise HTTPException(status_code=403, detail="No doctor assigned to this patient")

        target_doctor_id: OID | None = None
        if doctor_id:
            try:
                target_doctor_id = OID(doctor_id)
            except Exception:
                raise HTTPException(status_code=400, detail="Invalid doctor ID")
            if target_doctor_id not in patient.doctor_ids:
                raise HTTPException(status_code=403, detail="Doctor not assigned to this patient")
        else:
            target_doctor_id = patient.doctor_ids[0]

        if not target_doctor_id:
            raise HTTPException(status_code=403, detail="No doctor assigned to this patient")

        selected_doctor = await Doctor.get(target_doctor_id)
        if not selected_doctor:
            raise HTTPException(status_code=404, detail="Doctor not found")

    else:
        raise HTTPException(status_code=403, detail="Forbidden")

    patient_user_id = patient.user_id
    doctor_user_id = selected_doctor.user_id

    room = await ChatRoom.find_one(
        ChatRoom.patient_user_id == patient_user_id,
        ChatRoom.doctor_user_id == doctor_user_id,
    )

    if not room:
        room = await ChatRoom.find_one(
            ChatRoom.patient_id == patient.id,
            ChatRoom.doctor_id == selected_doctor.id,
        )

    if room:
        room = await ensure_chat_room_user_ids(room)
        updated = False
        if room.patient_id is None:
            room.patient_id = patient.id
            updated = True
        if room.doctor_id is None:
            room.doctor_id = selected_doctor.id
            updated = True
        if updated:
            await room.save()
    else:
        room = ChatRoom(
            patient_user_id=patient_user_id,
            doctor_user_id=doctor_user_id,
            patient_id=patient.id,
            doctor_id=selected_doctor.id,
        )
        await room.insert()

    return room

@router.get("/list", response_model=list[ChatListItemOut])
async def get_chat_list(current: User = Depends(get_current_user)):
    """جلب قائمة المحادثات للطبيب أو المريض مع آخر رسالة وعدد الرسائل غير المقروءة."""
    if current.role == Role.DOCTOR:
        doctor = await Doctor.find_one(Doctor.user_id == current.id)
        if not doctor:
            raise HTTPException(status_code=403, detail="Doctor profile not found")

        rooms = []
        primary_rooms = await ChatRoom.find(ChatRoom.doctor_user_id == current.id).to_list()
        legacy_rooms = await ChatRoom.find(
            ChatRoom.doctor_user_id == None,
            ChatRoom.doctor_id == doctor.id,
        ).to_list()

        seen_ids: set[str] = set()
        for room in primary_rooms + legacy_rooms:
            room_key = str(room.id)
            if room_key in seen_ids:
                continue
            seen_ids.add(room_key)
            rooms.append(room)

        result = []
        for room in rooms:
            room = await ensure_chat_room_user_ids(room)
            if room.patient_user_id is None:
                continue

            patient = await Patient.find_one(Patient.user_id == room.patient_user_id)
            if not patient:
                continue

            patient_user = await User.get(room.patient_user_id)
            if not patient_user:
                continue

            last_messages = await ChatMessage.find(
                ChatMessage.room_id == room.id
            ).sort(-ChatMessage.created_at).limit(1).to_list()
            last_message = last_messages[0] if last_messages else None

            unread_count = await ChatMessage.find(
                ChatMessage.room_id == room.id,
                ChatMessage.sender_user_id == room.patient_user_id,
                ChatMessage.is_read == False,
            ).count()

            last_message_text = None
            last_message_time = None
            if last_message:
                if last_message.imageUrl:
                    last_message_text = "صورة"
                else:
                    last_message_text = last_message.content
                last_message_time = last_message.created_at.isoformat()

            result.append(ChatListItemOut(
                patient_id=str(patient.id),
                patient_name=patient_user.name or patient.phone,
                patient_image_url=patient_user.imageUrl,
                last_message=last_message_text,
                last_message_time=last_message_time,
                unread_count=unread_count,
                room_id=str(room.id)
            ))

        result.sort(key=lambda x: x.last_message_time or "", reverse=True)
        return result
    
    elif current.role == Role.PATIENT:
        patient = await Patient.find_one(Patient.user_id == current.id)
        if not patient:
            raise HTTPException(status_code=404, detail="Patient not found")

        rooms = []
        primary_rooms = await ChatRoom.find(ChatRoom.patient_user_id == patient.user_id).to_list()
        legacy_rooms = await ChatRoom.find(
            ChatRoom.patient_user_id == None,
            ChatRoom.patient_id == patient.id,
        ).to_list()

        seen_ids: set[str] = set()
        for room in primary_rooms + legacy_rooms:
            room_key = str(room.id)
            if room_key in seen_ids:
                continue
            seen_ids.add(room_key)
            rooms.append(room)

        result = []
        for room in rooms:
            room = await ensure_chat_room_user_ids(room)
            if room.doctor_user_id is None:
                continue

            doctor_user = await User.get(room.doctor_user_id)
            if not doctor_user:
                continue

            last_messages = await ChatMessage.find(
                ChatMessage.room_id == room.id
            ).sort(-ChatMessage.created_at).limit(1).to_list()
            last_message = last_messages[0] if last_messages else None

            unread_count = await ChatMessage.find(
                ChatMessage.room_id == room.id,
                ChatMessage.sender_user_id == room.doctor_user_id,
                ChatMessage.is_read == False,
            ).count()

            last_message_text = None
            last_message_time = None
            if last_message:
                if last_message.imageUrl:
                    last_message_text = "صورة"
                else:
                    last_message_text = last_message.content
                last_message_time = last_message.created_at.isoformat()

            result.append(ChatListItemOut(
                patient_id=str(patient.id),
                patient_name=doctor_user.name or doctor_user.phone,
                patient_image_url=doctor_user.imageUrl,
                last_message=last_message_text,
                last_message_time=last_message_time,
                unread_count=unread_count,
                room_id=str(room.id)
            ))

        result.sort(key=lambda x: x.last_message_time or "", reverse=True)
        return result
    
    else:
        raise HTTPException(status_code=403, detail="Forbidden")

@router.get("/{patient_id}/messages", response_model=list[ChatMessageOut])
async def get_messages(
    patient_id: str, 
    limit: int = 50, 
    before: str | None = Query(None),
    doctor_id: str | None = Query(None, description="Doctor ID for patient to select specific doctor chat"),
    current: User = Depends(get_current_user)
):
    """استرجاع تاريخ الرسائل (أحدث أولاً) مع دعم before/limit."""
    room = await _get_or_room_for_user(patient_id=patient_id, user=current, doctor_id=doctor_id)
    
    # بناء الاستعلام
    query = ChatMessage.find(ChatMessage.room_id == room.id)
    
    if before:
        try:
            dt = datetime.fromisoformat(before.replace('Z', '+00:00'))
            query = query.find(ChatMessage.created_at < dt)
        except Exception:
            pass
    
    messages = await query.sort(-ChatMessage.created_at).limit(limit).to_list()
    
    return [
        ChatMessageOut(
            id=str(msg.id),
            room_id=str(msg.room_id),
            sender_user_id=str(msg.sender_user_id) if msg.sender_user_id else None,
            sender_role=msg.sender_role,
            content=msg.content,
            imageUrl=msg.imageUrl,
            is_read=msg.is_read,
            created_at=msg.created_at.isoformat()
        )
        for msg in messages
    ]

@router.post("/{patient_id}/messages", response_model=ChatMessageOut)
async def send_message(
    patient_id: str,
    content: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    doctor_id: str | None = Form(None, description="Doctor ID for patient to select specific doctor chat"),
    current: User = Depends(get_current_user)
):
    """إرسال رسالة جديدة (نصية أو مع صورة)."""
    room = await _get_or_room_for_user(patient_id=patient_id, user=current, doctor_id=doctor_id)
    
    # التحقق من وجود محتوى (نص أو صورة)
    if not content and not image:
        raise HTTPException(status_code=400, detail="يجب أن تحتوي الرسالة على نص أو صورة على الأقل")
    
    # رفع الصورة إذا كانت موجودة
    image_url = None
    if image:
        if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
            raise HTTPException(status_code=400, detail="نوع الملف غير مدعوم. فقط JPEG, PNG, WEBP")
        
        file_bytes = await image.read()
        # استخدام room_id كمعرف فريد لصورة الرسالة
        image_path = await upload_clinic_image(
            patient_id=str(room.id),
            folder="chat_images",
            file_bytes=file_bytes,
            content_type=image.content_type,
        )
        # upload_clinic_image now returns a direct /media/... URL
        image_url = image_path
    
    # إنشاء الرسالة
    message = ChatMessage(
        room_id=room.id,
        sender_user_id=current.id,
        sender_role=current.role,
        content=content or "",
        imageUrl=image_url,
        is_read=False
    )
    await message.insert()
    
    # إرسال الرسالة عبر Socket.IO إذا كان متاحاً
    try:
        from app.services.socket_service import emit_message_to_room
        
        # Determine receiver based on sender role
        if current.role == Role.DOCTOR:
            # If sender is doctor, receiver is patient
            receiver_id = str(room.patient_user_id) if room.patient_user_id else None
            receiver_role = Role.PATIENT
        elif current.role == Role.PATIENT:
            # If sender is patient, receiver is doctor
            receiver_id = str(room.doctor_user_id) if room.doctor_user_id else None
            receiver_role = Role.DOCTOR
        else:
            receiver_id = None
            receiver_role = None
        
        await emit_message_to_room(str(room.id), {
            "id": str(message.id),
            "room_id": str(message.room_id),
            "sender_user_id": str(message.sender_user_id) if message.sender_user_id else None,
            "sender_role": message.sender_role,
            "receiver_id": receiver_id,
            "receiver_role": receiver_role,
            "content": message.content,
            "imageUrl": message.imageUrl,
            "is_read": message.is_read,
            "created_at": message.created_at.isoformat()
        })
    except Exception as e:
        # لا نفشل الطلب إذا فشل Socket.IO
        print(f"⚠️ Failed to emit message via Socket.IO: {e}")
    
    # Determine receiver for logging
    if current.role == Role.DOCTOR:
        receiver_id = str(room.patient_user_id) if room.patient_user_id else None
        receiver_role = Role.PATIENT
    elif current.role == Role.PATIENT:
        receiver_id = str(room.doctor_user_id) if room.doctor_user_id else None
        receiver_role = Role.DOCTOR
    else:
        receiver_id = None
        receiver_role = None
    
    logger.info(
        f"📨 [REST] Message saved - Room: {room.id}, "
        f"Sender: {current.id} (role={current.role}), "
        f"Receiver: {receiver_id} (role={receiver_role}), "
        f"sender_user_id={message.sender_user_id}, sender_role={message.sender_role}"
    )

    return ChatMessageOut(
        id=str(message.id),
        room_id=str(message.room_id),
        sender_user_id=str(message.sender_user_id) if message.sender_user_id else None,
        sender_role=message.sender_role,
        content=message.content,
        imageUrl=message.imageUrl,
        is_read=message.is_read,
        created_at=message.created_at.isoformat()
    )

@router.put("/rooms/{room_id}/messages/{message_id}/read", response_model=ChatMessageOut)
async def mark_message_as_read(
    room_id: str,
    message_id: str,
    current: User = Depends(get_current_user)
):
    """تعليم رسالة كمقروءة."""
    try:
        room = await ChatRoom.get(OID(room_id))
    except Exception:
        raise HTTPException(status_code=404, detail="Conversation not found")

    room = await ensure_chat_room_user_ids(room)

    if current.role == Role.DOCTOR:
        if room.doctor_user_id != current.id:
            raise HTTPException(status_code=403, detail="Forbidden")
    elif current.role == Role.PATIENT:
        if room.patient_user_id != current.id:
            raise HTTPException(status_code=403, detail="Forbidden")
    else:
        raise HTTPException(status_code=403, detail="Forbidden")

    try:
        message = await ChatMessage.get(OID(message_id))
    except Exception:
        raise HTTPException(status_code=404, detail="Message not found")

    if message.room_id != room.id:
        raise HTTPException(status_code=403, detail="Forbidden")

    message.is_read = True
    await message.save()

    return ChatMessageOut(
        id=str(message.id),
        room_id=str(message.room_id),
        sender_user_id=str(message.sender_user_id) if message.sender_user_id else None,
        sender_role=message.sender_role,
        content=message.content,
        imageUrl=message.imageUrl,
        is_read=message.is_read,
        created_at=message.created_at.isoformat()
    )
