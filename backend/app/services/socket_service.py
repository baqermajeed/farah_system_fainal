"""
Socket.IO service for real-time chat communication.
"""
import socketio
from typing import Dict, Set
from beanie import PydanticObjectId as OID
from app.models import User, Patient, Doctor, ChatRoom, ChatMessage
from app.constants import Role
from app.utils.chat_helpers import ensure_chat_room_user_ids
from jose import jwt, JWTError
from app.config import get_settings

settings = get_settings()

# Create Socket.IO server
sio = socketio.AsyncServer(
    cors_allowed_origins="*",
    async_mode='asgi',
    logger=True,
    engineio_logger=True
)

# Store active connections: userId -> Set of socketIds
active_connections: Dict[str, Set[str]] = {}

# Store socket rooms: socketId -> Set of roomIds
socket_rooms: Dict[str, Set[str]] = {}

# Store user data per socket: socketId -> user_data
socket_users: Dict[str, dict] = {}


@sio.on('connect')
async def connect(sid: str, environ: dict, auth: dict):
    """Handle socket connection with authentication."""
    try:
        # Get token from auth or headers
        token = None
        if auth:
            token = auth.get('token')
        if not token and environ:
            auth_header = environ.get('HTTP_AUTHORIZATION', '')
            if auth_header.startswith('Bearer '):
                token = auth_header.replace('Bearer ', '')
        
        if not token:
            print(f"❌ Connection rejected for {sid}: No token")
            await sio.disconnect(sid)
            return False
        
        # Decode JWT
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        user_id_str = payload.get("sub")
        if not user_id_str:
            print(f"❌ Connection rejected for {sid}: No user ID in token")
            await sio.disconnect(sid)
            return False
        
        user_id = OID(user_id_str)
        user = await User.get(user_id)
        if not user:
            print(f"❌ Connection rejected for {sid}: User not found")
            await sio.disconnect(sid)
            return False
        
        # Store user data
        socket_users[sid] = {
            'user_id': str(user.id),
            'user': user,
            'role': payload.get("role")
        }
        
        # Track active connection
        user_id_key = str(user.id)
        if user_id_key not in active_connections:
            active_connections[user_id_key] = set()
        active_connections[user_id_key].add(sid)
        socket_rooms[sid] = set()
        
        # Join user's personal room
        await sio.enter_room(sid, f"user_{user_id_key}")
        
        print(f"✅ User connected: {user_id_key} ({user.name}) - Socket: {sid}")
        return True
    except Exception as e:
        print(f"❌ Connection error for {sid}: {e}")
        await sio.disconnect(sid)
        return False


@sio.on('disconnect')
async def disconnect(sid: str):
    """Handle socket disconnection."""
    # Get user data
    user_data = socket_users.pop(sid, None)
    user_id = user_data.get('user_id') if user_data else None
    
    # Remove from active connections
    if user_id and user_id in active_connections:
        active_connections[user_id].discard(sid)
        if not active_connections[user_id]:
            active_connections.pop(user_id, None)
    
    # Remove socket rooms
    socket_rooms.pop(sid, None)
    
    if user_id:
        print(f"❌ User disconnected: {user_id} - Socket: {sid}")
    else:
        print(f"❌ Socket disconnected: {sid}")


@sio.on('join_conversation')
async def join_conversation(sid: str, data: dict):
    """Join a conversation room."""
    try:
        patient_id = data.get('patient_id')
        if not patient_id:
            await sio.emit('error', {'message': 'معرف المريض مطلوب', 'code': 'E400'}, room=sid)
            return
        
        user_data = socket_users.get(sid)
        if not user_data:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E401'}, room=sid)
            return
        
        user_id = user_data['user_id']
        user = user_data['user']
        
        try:
            patient = await Patient.get(OID(patient_id))
        except Exception:
            await sio.emit('error', {'message': 'المريض غير موجود', 'code': 'E404'}, room=sid)
            return
        
        requested_doctor_id = data.get('doctor_id')
        selected_doctor: Doctor | None = None
        doctor_user_id: str | None = None
        patient_user_id = patient.user_id

        if user.role == Role.DOCTOR:
            selected_doctor = await Doctor.find_one(Doctor.user_id == user.id)
            if not selected_doctor or selected_doctor.id not in patient.doctor_ids:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
            doctor_user_id = user.id
        elif user.role == Role.PATIENT:
            if patient.user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
            if not patient.doctor_ids:
                await sio.emit('error', {'message': 'لا يوجد طبيب معين', 'code': 'E403'}, room=sid)
                return

            target_doctor_id: OID | None = None
            if requested_doctor_id:
                try:
                    target_doctor_id = OID(requested_doctor_id)
                except Exception:
                    await sio.emit('error', {'message': 'معرف الطبيب غير صالح', 'code': 'E400'}, room=sid)
                    return
                if target_doctor_id not in patient.doctor_ids:
                    await sio.emit('error', {'message': 'الطبيب غير مرتبط بهذا المريض', 'code': 'E403'}, room=sid)
                    return
            else:
                target_doctor_id = patient.doctor_ids[0]

            if not target_doctor_id:
                await sio.emit('error', {'message': 'الطبيب غير مرتبط بهذا المريض', 'code': 'E403'}, room=sid)
                return

            selected_doctor = await Doctor.get(target_doctor_id)
            if not selected_doctor:
                await sio.emit('error', {'message': 'الطبيب غير موجود', 'code': 'E404'}, room=sid)
                return
            doctor_user_id = selected_doctor.user_id
        else:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
            return
        
        if doctor_user_id is None or selected_doctor is None:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
            return

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

        room_key = f"room_{room.id}"
        await sio.enter_room(sid, room_key)
        
        if sid in socket_rooms:
            socket_rooms[sid].add(str(room.id))
        
        print(f"👤 User {user_id} joined conversation {room.id}")
        await sio.emit('joined_conversation', {'room_id': str(room.id), 'patient_id': patient_id}, room=sid)
    except Exception as e:
        print(f"❌ Error joining conversation: {e}")
        await sio.emit('error', {'message': f'خطأ في الانضمام للمحادثة: {str(e)}', 'code': 'E500'}, room=sid)


@sio.on('join_room_by_id')
async def join_room_by_id(sid: str, data: dict):
    """Join a conversation room by room_id directly."""
    try:
        room_id = data.get('room_id')
        if not room_id:
            await sio.emit('error', {'message': 'معرف المحادثة مطلوب', 'code': 'E400'}, room=sid)
            return

        user_data = socket_users.get(sid)
        if not user_data:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E401'}, room=sid)
            return

        user_id = user_data['user_id']
        user = user_data['user']

        try:
            room = await ChatRoom.get(OID(room_id))
        except Exception:
            await sio.emit('error', {'message': 'المحادثة غير موجودة', 'code': 'E404'}, room=sid)
            return

        room = await ensure_chat_room_user_ids(room)

        if user.role == Role.DOCTOR:
            if room.doctor_user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
        elif user.role == Role.PATIENT:
            if room.patient_user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
        else:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
            return

        room_key = f"room_{room.id}"
        await sio.enter_room(sid, room_key)

        if sid not in socket_rooms:
            socket_rooms[sid] = set()
        socket_rooms[sid].add(str(room.id))

        patient_payload_id = str(room.patient_id) if room.patient_id else None
        if not patient_payload_id and room.patient_user_id:
            linked_patient = await Patient.find_one(Patient.user_id == room.patient_user_id)
            if linked_patient:
                patient_payload_id = str(linked_patient.id)

        print(f"👤 User {user_id} joined room {room.id} by room_id")
        await sio.emit('joined_conversation', {
            'room_id': str(room.id),
            'patient_id': patient_payload_id,
        }, room=sid)
    except Exception as e:
        print(f"❌ Error joining room by id: {e}")
        await sio.emit('error', {'message': f'خطأ في الانضمام للمحادثة: {str(e)}', 'code': 'E500'}, room=sid)


@sio.on('leave_conversation')
async def leave_conversation(sid: str, data: dict):
    """Leave a conversation room."""
    try:
        room_id = data.get('room_id')
        if room_id:
            room_key = f"room_{room_id}"
            await sio.leave_room(sid, room_key)
            
            # Remove from tracking
            if sid in socket_rooms:
                socket_rooms[sid].discard(room_id)
            
            print(f"👋 Socket {sid} left conversation {room_id}")
            await sio.emit('left_conversation', {'room_id': room_id}, room=sid)
    except Exception as e:
        print(f"❌ Error leaving conversation: {e}")


@sio.on('send_message')
async def send_message(sid: str, data: dict):
    """Send a text message using room_id."""
    try:
        room_id = data.get('room_id')
        content = data.get('content', '').strip()
        image_url = data.get('image_url')
        
        if not room_id:
            await sio.emit('error', {'message': 'معرف المحادثة مطلوب', 'code': 'E400'}, room=sid)
            return
        
        if not content and not image_url:
            await sio.emit('error', {'message': 'يجب أن تحتوي الرسالة على نص أو صورة', 'code': 'E400'}, room=sid)
            return
        
        # Get user from socket
        user_data = socket_users.get(sid)
        if not user_data:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E401'}, room=sid)
            return
        
        user_id = user_data['user_id']
        user = user_data['user']
        
        # Get room and verify access
        try:
            room = await ChatRoom.get(OID(room_id))
        except Exception:
            await sio.emit('error', {'message': 'المحادثة غير موجودة', 'code': 'E404'}, room=sid)
            return
        
        room = await ensure_chat_room_user_ids(room)
        if user.role == Role.DOCTOR:
            if room.doctor_user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
        elif user.role == Role.PATIENT:
            if room.patient_user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
        else:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
            return
        
        # Create message
        message = ChatMessage(
            room_id=room.id,
            sender_user_id=user.id,
            sender_role=user.role,
            content=content or "",
            imageUrl=image_url,
            is_read=False
        )
        await message.insert()
        
        # Broadcast to room
        room_key = f"room_{room.id}"
        
        # Determine receiver based on sender role
        if user.role == Role.DOCTOR:
            # If sender is doctor, receiver is patient
            receiver_id = str(room.patient_user_id) if room.patient_user_id else None
            receiver_role = Role.PATIENT
        elif user.role == Role.PATIENT:
            # If sender is patient, receiver is doctor
            receiver_id = str(room.doctor_user_id) if room.doctor_user_id else None
            receiver_role = Role.DOCTOR
        else:
            receiver_id = None
            receiver_role = None
        
        message_data = {
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
        }
        
        await sio.emit('message_received', {'message': message_data}, room=room_key)
        await sio.emit('message_sent', {'message': message_data}, room=sid)
        
        print(f"📨 [Socket] Message sent - Room: {room.id}, Sender: {user_id} (role={user.role}), Receiver: {receiver_id} (role={receiver_role})")
        print(f"    Message data: sender_user_id={message_data['sender_user_id']}, sender_role={message_data['sender_role']}, receiver_id={receiver_id}")
    except Exception as e:
        print(f"❌ Error sending message: {e}")
        await sio.emit('error', {'message': f'خطأ في إرسال الرسالة: {str(e)}', 'code': 'E500'}, room=sid)


@sio.on('mark_read')
async def mark_read(sid: str, data: dict):
    """Mark messages as read."""
    try:
        room_id = data.get('room_id')
        if not room_id:
            await sio.emit('error', {'message': 'معرف المحادثة مطلوب', 'code': 'E400'}, room=sid)
            return
        
        # Get user from socket
        user_data = socket_users.get(sid)
        if not user_data:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E401'}, room=sid)
            return
        
        user_id = user_data['user_id']
        user = user_data['user']
        
        # Mark messages as read
        room = await ChatRoom.get(OID(room_id))
        if not room:
            await sio.emit('error', {'message': 'المحادثة غير موجودة', 'code': 'E404'}, room=sid)
            return
        
        room = await ensure_chat_room_user_ids(room)
        if user.role == Role.DOCTOR:
            if room.doctor_user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
        elif user.role == Role.PATIENT:
            if room.patient_user_id != user.id:
                await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
                return
        else:
            await sio.emit('error', {'message': 'غير مصرح', 'code': 'E403'}, room=sid)
            return

        from beanie.operators import Set as UpdateSet
        await ChatMessage.find(
            ChatMessage.room_id == room.id,
            ChatMessage.sender_user_id != user.id,
            ChatMessage.is_read == False
        ).update(UpdateSet({"is_read": True}))
        
        await sio.emit('marked_read', {'room_id': room_id}, room=sid)
    except Exception as e:
        print(f"❌ Error marking messages as read: {e}")
        await sio.emit('error', {'message': f'خطأ في تعليم الرسائل كمقروءة: {str(e)}', 'code': 'E500'}, room=sid)


async def emit_message_to_room(room_id: str, message_data: dict):
    """Emit message to a room (called from HTTP endpoints)."""
    try:
        room_key = f"room_{room_id}"
        await sio.emit('message_received', {'message': message_data}, room=room_key)
    except Exception as e:
        print(f"⚠️ Failed to emit message to room {room_id}: {e}")


def get_socket_app():
    """Get Socket.IO ASGI app."""
    return socketio.ASGIApp(sio, socketio_path='socket.io')

