from datetime import datetime
from pathlib import Path
from typing import Optional

import boto3
from fastapi import HTTPException

from app.config import get_settings
from app.utils.logger import get_logger

settings = get_settings()
logger = get_logger("r2")


def _ext_from_content_type(content_type: Optional[str]) -> str:
    if not content_type:
        return ""
    ct = content_type.lower()
    if ct in ("image/jpeg", "image/jpg"):
        return ".jpg"
    if ct == "image/png":
        return ".png"
    if ct == "image/webp":
        return ".webp"
    if ct == "image/gif":
        return ".gif"
    if ct == "image/heic":
        return ".heic"
    if ct == "image/heif":
        return ".heif"
    return ""


def _sanitize_name_hint(name_hint: Optional[str]) -> str:
    if not name_hint:
        return ""
    cleaned = "".join(ch if ch.isalnum() else "_" for ch in name_hint.strip().replace(" ", "_"))
    return cleaned.strip("_")


def _get_r2_client():
    if not (
        settings.R2_ACCOUNT_ID
        and settings.R2_ACCESS_KEY_ID
        and settings.R2_SECRET_ACCESS_KEY
        and settings.R2_BUCKET_NAME
        and settings.R2_PUBLIC_BASE
    ):
        return None

    session = boto3.session.Session()
    return session.client(
        "s3",
        endpoint_url=f"https://{settings.R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=settings.R2_ACCESS_KEY_ID,
        aws_secret_access_key=settings.R2_SECRET_ACCESS_KEY,
        region_name="auto",
    )


async def upload_clinic_image(
    patient_id: str,
    folder: str,
    file_bytes: bytes,
    content_type: str = "image/jpeg",
    name_hint: Optional[str] = None,
) -> str:
    if not patient_id or not folder or not file_bytes:
        raise HTTPException(status_code=400, detail="Missing upload information")

    ts = datetime.utcnow().strftime("%Y%m%d%H%M%S%f")
    ext = _ext_from_content_type(content_type)
    prefix = _sanitize_name_hint(name_hint)
    file_name = f"{prefix + '_' if prefix else ''}{ts}{ext}"
    dir_label = f"{prefix or 'patient'}_{patient_id}"
    key = f"patients/{dir_label}/{folder}/{file_name}"

    client = _get_r2_client()
    if client:
        try:
            client.put_object(
                Bucket=settings.R2_BUCKET_NAME,
                Key=key,
                Body=file_bytes,
                ContentType=content_type,
            )
            safe_key = key.encode("ascii", "ignore").decode("ascii")
            logger.info("Uploaded file to R2: %s", safe_key or key)
            return f"{settings.R2_PUBLIC_BASE.rstrip('/')}/{key}"
        except Exception as exc:
            logger.error(f"Failed to upload to R2 ({key}): {exc}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to upload media file")

    media_dir = Path(__file__).resolve().parents[2] / "media"
    local_file_path = media_dir / key
    local_file_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        with open(local_file_path, "wb") as f:
            f.write(file_bytes)
        logger.info(f"Saved file locally to: {local_file_path}")
        return f"/media/{key}"
    except Exception as e:
        logger.error(f"Failed to save file locally: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to save media file")


