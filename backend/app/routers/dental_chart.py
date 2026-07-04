"""API مخطط الأسنان (Dental Chart / FDI) في بروفايل المريض."""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException

from app.schemas import (
    DentalChartOut,
    DentalChartUpsert,
    DentalToothPatch,
    DentalNoteEntryOut,
)
from app.security import require_roles, get_current_user
from app.constants import Role
from app.services import dental_chart_service
from app.models import Doctor
from app.models.dental_chart import DentalChart

router = APIRouter(
    prefix="/patients/{patient_id}/dental-chart",
    tags=["dental-chart"],
)


def _iso(dt: Optional[datetime]) -> str:
    if not dt:
        return datetime.now(timezone.utc).isoformat()
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat()


def _notes_to_out(notes: Any) -> Dict[str, List[DentalNoteEntryOut]]:
    result: Dict[str, List[DentalNoteEntryOut]] = {}
    if not notes:
        return result

    for tooth, entries in notes.items():
        out_entries: List[DentalNoteEntryOut] = []
        if not entries:
            continue
        for entry in entries:
            if hasattr(entry, "text"):
                text = entry.text
                created = getattr(entry, "created_at", None)
            elif isinstance(entry, dict):
                text = entry.get("text") or entry.get("note") or ""
                created = entry.get("created_at") or entry.get("createdAt")
            else:
                continue
            text = str(text).strip()
            if not text:
                continue
            if isinstance(created, datetime):
                created_s = _iso(created)
            elif isinstance(created, str) and created.strip():
                created_s = created
            else:
                created_s = _iso(None)
            out_entries.append(DentalNoteEntryOut(text=text, createdAt=created_s))
        if out_entries:
            result[str(tooth)] = out_entries
    return result


def _chart_to_out(doc: DentalChart) -> DentalChartOut:
    return DentalChartOut(
        id=str(doc.id) if getattr(doc, "id", None) else None,
        patient_id=str(doc.patient_id),
        doctor_id=str(doc.doctor_id),
        chart={k: list(v) for k, v in (doc.chart or {}).items()},
        notes=_notes_to_out(doc.notes),
        selected_tooth=doc.selected_tooth,
        created_at=_iso(doc.created_at),
        updated_at=_iso(doc.updated_at),
    )


def _empty_out(*, patient_id: str, doctor_id: str) -> DentalChartOut:
    now = datetime.now(timezone.utc).isoformat()
    return DentalChartOut(
        id=None,
        patient_id=patient_id,
        doctor_id=doctor_id,
        chart={},
        notes={},
        selected_tooth=None,
        created_at=now,
        updated_at=now,
    )


async def _current_doctor_id(current) -> str:
    doctor = await Doctor.find_one(Doctor.user_id == current.id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor profile not found")
    return str(doctor.id)


def _notes_payload_from_upsert(
    notes: Dict[str, List[Any]],
) -> Dict[str, List[dict]]:
    payload: Dict[str, List[dict]] = {}
    for tooth, entries in (notes or {}).items():
        items: List[dict] = []
        for entry in entries or []:
            if hasattr(entry, "model_dump"):
                data = entry.model_dump()
            elif isinstance(entry, dict):
                data = entry
            else:
                continue
            items.append(
                {
                    "text": data.get("text"),
                    "createdAt": data.get("createdAt") or data.get("created_at"),
                    "created_at": data.get("created_at") or data.get("createdAt"),
                }
            )
        payload[str(tooth)] = items
    return payload


@router.get("", response_model=DentalChartOut)
async def get_dental_chart(
    patient_id: str,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """جلب مخطط الأسنان للمريض (خاص بالطبيب الحالي)."""
    doctor_id = await _current_doctor_id(current)
    doc = await dental_chart_service.get_dental_chart(
        patient_id=patient_id,
        doctor_id=doctor_id,
    )
    if not doc:
        return _empty_out(patient_id=patient_id, doctor_id=doctor_id)
    return _chart_to_out(doc)


@router.put("", response_model=DentalChartOut)
async def upsert_dental_chart(
    patient_id: str,
    payload: DentalChartUpsert,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """حفظ/استبدال مخطط الأسنان بالكامل.

    يطابق سلوك الواجهة عند _persistDentalData:
    - chart + notes فارغان => حذف المخطط
    - غير ذلك => إنشاء أو تحديث سجل واحد لكل (مريض، طبيب)
    """
    doctor_id = await _current_doctor_id(current)
    selected = payload.selected_tooth or payload.selectedTooth

    doc = await dental_chart_service.upsert_dental_chart(
        patient_id=patient_id,
        doctor_id=doctor_id,
        chart=payload.chart,
        notes=_notes_payload_from_upsert(payload.notes),
        selected_tooth=selected,
    )

    # بعد الحذف المنطقي لا يوجد id في قاعدة البيانات
    if not doc.chart and not doc.notes:
        return _empty_out(patient_id=patient_id, doctor_id=doctor_id)

    return _chart_to_out(doc)


@router.patch("/teeth/{tooth_no}", response_model=DentalChartOut)
async def patch_dental_tooth(
    patient_id: str,
    tooth_no: str,
    payload: DentalToothPatch,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """تحديث حالات/ملاحظات سن واحد."""
    doctor_id = await _current_doctor_id(current)

    notes_payload = None
    if payload.notes is not None:
        notes_payload = _notes_payload_from_upsert({tooth_no: payload.notes}).get(
            tooth_no, []
        )

    doc = await dental_chart_service.patch_tooth(
        patient_id=patient_id,
        doctor_id=doctor_id,
        tooth_no=tooth_no,
        statuses=payload.statuses,
        notes=notes_payload,
        clear=payload.clear,
    )

    if not doc.chart and not doc.notes:
        return _empty_out(patient_id=patient_id, doctor_id=doctor_id)

    return _chart_to_out(doc)


@router.delete("")
async def delete_dental_chart(
    patient_id: str,
    current=Depends(require_roles([Role.DOCTOR])),
):
    """حذف مخطط الأسنان بالكامل لهذا الطبيب."""
    doctor_id = await _current_doctor_id(current)
    deleted = await dental_chart_service.delete_dental_chart(
        patient_id=patient_id,
        doctor_id=doctor_id,
    )
    return {"ok": True, "deleted": deleted}


meta_router = APIRouter(prefix="/dental-chart", tags=["dental-chart"])


@meta_router.get("/meta")
async def dental_chart_meta(current=Depends(get_current_user)):
    """قائمة الحالات والأسنان المدعومة (مرجع للواجهة)."""
    return {
        "fdi_teeth": {
            "upper": [
                "18", "17", "16", "15", "14", "13", "12", "11",
                "21", "22", "23", "24", "25", "26", "27", "28",
            ],
            "lower": [
                "48", "47", "46", "45", "44", "43", "42", "41",
                "31", "32", "33", "34", "35", "36", "37", "38",
            ],
        },
        "statuses": sorted(dental_chart_service.DENTAL_STATUSES),
        "sub_statuses": {
            "حشوة": [
                "حشوة تجميلية",
                "حشوة جذر",
                "حشوة معدنية",
                "حشوة مختبرية",
            ],
            "تاج": [
                "زركون",
                "سيراميك",
                "اي ماكس",
            ],
            "ابتسامة": [
                "فك علوي",
                "فك سفلي",
            ],
        },
    }
