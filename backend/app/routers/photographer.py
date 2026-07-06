from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException, Form
from beanie.operators import In
from datetime import datetime, timezone

from app.schemas import GalleryOut, GalleryCreate, PatientOut
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services.patient_service import create_gallery_image
from app.utils.r2_clinic import upload_clinic_image
from app.models import Patient, User
from app.utils.patient_out import build_patient_out, patient_name_hint_for_id

IMAGE_TYPES = ("image/jpeg", "image/png", "image/webp")
MAX_IMAGE_MB = 10

router = APIRouter(prefix="/photographer", tags=["photographer"], dependencies=[Depends(require_roles([Role.PHOTOGRAPHER]))])

@router.get("/patients", response_model=list[PatientOut])
async def list_patients(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """قائمة جميع المرضى للمصور بهدف اختيار مريض لإرفاق الصور."""
    patients = await Patient.find({}).skip(skip).limit(limit).to_list()
    user_ids = list({p.user_id for p in patients if p.user_id})
    users = await User.find(In(User.id, user_ids)).to_list() if user_ids else []
    user_map = {u.id: u for u in users}

    out: list[PatientOut] = []
    for p in patients:
        u = user_map.get(p.user_id)
        out.append(build_patient_out(p, u))
    return out

@router.post("/patients/{patient_id}/gallery", response_model=GalleryOut)
async def upload_patient_image(
    patient_id: str,
    note: str | None = Form(None),
    image: UploadFile = File(...),
    current=Depends(get_current_user),
):
    """المصور يرفع صورة للمريض مع ملاحظة اختيارية."""
    if IMAGE_TYPES and image.content_type not in IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed types: {', '.join(IMAGE_TYPES)}",
        )
    file_bytes = await image.read()
    patient_name_hint = await patient_name_hint_for_id(patient_id)
    image_path = await upload_clinic_image(
        patient_id=patient_id,
        folder="gallery",
        file_bytes=file_bytes,
        content_type=image.content_type,
        name_hint=patient_name_hint,
    )
    gi = await create_gallery_image(
        patient_id=patient_id,
        uploaded_by_user_id=str(current.id),
        image_path=image_path,
        note=note,
    )
    return GalleryOut(
        id=str(gi.id),
        patient_id=str(gi.patient_id),
        image_path=gi.image_path,
        note=gi.note,
        created_at=gi.created_at.isoformat() if gi.created_at else datetime.now(timezone.utc).isoformat(),
    )
