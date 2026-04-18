from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException, Form
from beanie.operators import In
from datetime import datetime, timezone

from app.schemas import GalleryOut, GalleryCreate, PatientOut
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services.patient_service import create_gallery_image
from app.utils.r2_clinic import upload_clinic_image
from app.models import Patient, User
from app.utils.patient_profile import build_doctor_profile_map

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
        out.append(PatientOut(
            id=str(p.id),
            user_id=str(p.user_id),
            name=u.name if u else None,
            phone=u.phone if u else "",
            gender=u.gender if u else None,
            age=u.age if u else None,
            city=u.city if u else None,
            treatment_type=p.treatment_type,
            visit_type=getattr(p, "visit_type", None),
            consultation_type=getattr(p, "consultation_type", None),
            payment_methods=getattr(p, "payment_methods", None),
            doctor_ids=[str(did) for did in p.doctor_ids],
            doctor_profiles=build_doctor_profile_map(p),
            qr_code_data=p.qr_code_data,
            qr_image_path=p.qr_image_path,
            imageUrl=u.imageUrl if u else None,
            created_at=p.created_at.isoformat() if getattr(p, "created_at", None) else None,
        ))
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
    image_path = await upload_clinic_image(
        patient_id=patient_id,
        folder="gallery",
        file_bytes=file_bytes,
        content_type=image.content_type,
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
