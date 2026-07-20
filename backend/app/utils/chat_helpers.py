from app.models import ChatRoom, Patient, Doctor


async def ensure_chat_room_user_ids(room: ChatRoom) -> ChatRoom:
    """
    Populate missing user-level identifiers for a chat room and persist the changes.
    This keeps existing chat documents compatible while allowing newer logic to rely on
    `patient_user_id` and `doctor_user_id`.
    """
    updated = False

    if room.patient_user_id is None and room.patient_id is not None:
        patient = await Patient.get(room.patient_id)
        if patient:
            room.patient_user_id = patient.user_id
            updated = True

    if room.doctor_user_id is None and room.doctor_id is not None:
        doctor = await Doctor.get(room.doctor_id)
        if doctor:
            room.doctor_user_id = doctor.user_id
            updated = True

    if updated:
        await room.save()

    return room


async def get_or_create_chat_room(*, patient: Patient, doctor: Doctor) -> ChatRoom:
    """
    غرفة واحدة لكل (patient_id + doctor_id).
    مهم للعائلة: نفس user_id لا يكفي — كل فرد له غرفة مستقلة.
    """
    patient_user_id = patient.user_id
    doctor_user_id = doctor.user_id

    room = await ChatRoom.find_one(
        ChatRoom.patient_id == patient.id,
        ChatRoom.doctor_id == doctor.id,
    )

    if not room:
        legacy_room = await ChatRoom.find_one(
            ChatRoom.patient_user_id == patient_user_id,
            ChatRoom.doctor_user_id == doctor_user_id,
        )
        # لا نعيد استخدام غرفة فرد آخر من نفس رقم الهاتف
        if legacy_room and (
            legacy_room.patient_id is None or legacy_room.patient_id == patient.id
        ):
            room = legacy_room

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
        return room

    room = ChatRoom(
        patient_user_id=patient_user_id,
        doctor_user_id=doctor_user_id,
        patient_id=patient.id,
        doctor_id=doctor.id,
    )
    await room.insert()
    return room
