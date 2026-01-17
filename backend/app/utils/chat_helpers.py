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

