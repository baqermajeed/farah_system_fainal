from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from beanie import PydanticObjectId as OID

from app.constants import Role
from app.services.chat_service import ConnectionManager
from app.models import ChatRoom, ChatMessage, Patient, User, Doctor
from app.utils.chat_helpers import ensure_chat_room_user_ids

router = APIRouter(prefix="/ws", tags=["chat"])
manager = ConnectionManager()

async def _get_room_for_pair(patient: Patient, doctor: Doctor) -> ChatRoom:
    """Ensure a chat room exists for the given patient/doctor pair and populate user IDs."""
    room = await ChatRoom.find_one(
        ChatRoom.patient_user_id == patient.user_id,
        ChatRoom.doctor_user_id == doctor.user_id,
    )
    if not room:
        room = await ChatRoom.find_one(
            ChatRoom.patient_id == patient.id,
            ChatRoom.doctor_id == doctor.id,
        )

    if room:
        room = await ensure_chat_room_user_ids(room)
        updated = False
        if room.patient_id is None:
            room.patient_id = patient.id
            updated = True
        if room.doctor_id is None:
            room.doctor_id = doctor.id
            updated = True
        if updated:
            await room.save()
    else:
        room = ChatRoom(
            patient_user_id=patient.user_id,
            doctor_user_id=doctor.user_id,
            patient_id=patient.id,
            doctor_id=doctor.id,
        )
        await room.insert()

    return room

@router.websocket("/chat/{patient_id}")
async def chat_ws(websocket: WebSocket, patient_id: str, token: str = Query("")):
    """قناة محادثة مباشرة بين الطبيب والمريض عبر WebSocket."""
    from jose import jwt, JWTError
    from app.config import get_settings

    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        user_id_str = payload.get("sub")
        if not user_id_str:
            await websocket.close(code=4401)
            return
        user_id = OID(user_id_str)
    except Exception:
        await websocket.close(code=4401)
        return

    try:
        user = await User.get(user_id)
    except Exception:
        user = None

    if not user:
        await websocket.close(code=4401)
        return

    try:
        patient = await Patient.get(OID(patient_id))
    except Exception:
        patient = None

    if not patient:
        await websocket.close(code=4404)
        return

    selected_doctor: Doctor | None = None
    if user.role == Role.DOCTOR:
        selected_doctor = await Doctor.find_one(Doctor.user_id == user.id)
        if not selected_doctor or selected_doctor.id not in patient.doctor_ids:
            await websocket.close(code=4403, reason="Doctor not assigned to this patient")
            return
    elif user.role == Role.PATIENT:
        if patient.user_id != user.id:
            await websocket.close(code=4403)
            return
        if not patient.doctor_ids:
            await websocket.close(code=4403, reason="No doctor assigned to this patient")
            return
        doctor_id = patient.doctor_ids[0]
        selected_doctor = await Doctor.get(doctor_id)
        if not selected_doctor:
            await websocket.close(code=4403, reason="Doctor profile not found")
            return
    else:
        await websocket.close(code=4403)
        return

    room = await _get_room_for_pair(patient=patient, doctor=selected_doctor)
    room_key = f"room:{room.id}"

    await manager.connect(room_key, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            content = str(data.get("message", "")).strip()
            if not content:
                continue
            msg = ChatMessage(room_id=room.id, sender_user_id=user.id, content=content)
            await msg.insert()
            await manager.broadcast(room_key, {
                "sender_id": str(user.id),
                "message": content,
                "room_id": str(room.id)
            })
    except WebSocketDisconnect:
        await manager.disconnect(room_key, websocket)
