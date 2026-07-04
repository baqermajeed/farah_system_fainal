"""خدمة مخطط الأسنان (Dental Chart / FDI).

يطابق بنية الواجهة في doctor_home_screen:
- chart: tooth_no -> [status, ...]
- notes: tooth_no -> [{text, createdAt}, ...]
- selected_tooth اختياري
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

from beanie import PydanticObjectId as OID
from fastapi import HTTPException

from app.models import Patient
from app.models.dental_chart import DentalChart, DentalNoteEntry

# أسنان FDI المستخدمة في الواجهة
FDI_TEETH = {
    # علوي
    "18", "17", "16", "15", "14", "13", "12", "11",
    "21", "22", "23", "24", "25", "26", "27", "28",
    # سفلي
    "48", "47", "46", "45", "44", "43", "42", "41",
    "31", "32", "33", "34", "35", "36", "37", "38",
}

# الحالات الأساسية (مطابقة لـ _dentalStatuses)
DENTAL_STATUSES = {
    "زراعة",
    "قلع",
    "مفقود",
    "تاج",
    "حشوة",
    "جسر",
    "قص لثة",
    "فينير",
    "تسوس",
}

# الحالات الفرعية (مطابقة لـ _dentalSubStatuses)
DENTAL_SUB_STATUSES = {
    "حشوة تجميلية",
    "حشوة جذر",
    "حشوة معدنية",
    "حشوة مختبرية",
    "زركون",
    "سيراميك",
    "اي ماكس",
}

ALLOWED_STATUSES = DENTAL_STATUSES | DENTAL_SUB_STATUSES


def _parse_note_created_at(raw: Any) -> datetime:
    if isinstance(raw, datetime):
        if raw.tzinfo is None:
            return raw.replace(tzinfo=timezone.utc)
        return raw
    if isinstance(raw, str) and raw.strip():
        try:
            dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def _normalize_chart(chart: Optional[Dict[str, Any]]) -> Dict[str, List[str]]:
    if not chart:
        return {}

    normalized: Dict[str, List[str]] = {}
    for tooth, statuses in chart.items():
        tooth_no = str(tooth).strip()
        if tooth_no not in FDI_TEETH:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid FDI tooth number: {tooth_no}",
            )

        if statuses is None:
            continue

        if isinstance(statuses, str):
            status_list = [statuses] if statuses.strip() else []
        elif isinstance(statuses, list):
            status_list = [str(s).strip() for s in statuses if str(s).strip()]
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid statuses for tooth {tooth_no}",
            )

        for status in status_list:
            if status not in ALLOWED_STATUSES:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid dental status '{status}' for tooth {tooth_no}",
                )

        # إزالة التكرار مع الحفاظ على الترتيب
        seen: set[str] = set()
        unique: List[str] = []
        for status in status_list:
            if status not in seen:
                seen.add(status)
                unique.append(status)

        if unique:
            normalized[tooth_no] = unique

    return normalized


def _normalize_notes(
    notes: Optional[Dict[str, Any]],
) -> Dict[str, List[DentalNoteEntry]]:
    if not notes:
        return {}

    normalized: Dict[str, List[DentalNoteEntry]] = {}
    for tooth, entries in notes.items():
        tooth_no = str(tooth).strip()
        if tooth_no not in FDI_TEETH:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid FDI tooth number in notes: {tooth_no}",
            )

        parsed_entries: List[DentalNoteEntry] = []

        if isinstance(entries, dict):
            # صيغة قديمة: ملاحظة واحدة لكل سن
            entries = [entries]
        elif entries is None:
            entries = []
        elif not isinstance(entries, list):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid notes format for tooth {tooth_no}",
            )

        for item in entries:
            if not isinstance(item, dict):
                continue
            text = (
                item.get("text")
                or item.get("note")
                or ""
            )
            text = str(text).strip()
            if not text:
                continue
            created_raw = (
                item.get("createdAt")
                or item.get("created_at")
            )
            parsed_entries.append(
                DentalNoteEntry(
                    text=text,
                    created_at=_parse_note_created_at(created_raw),
                )
            )

        if parsed_entries:
            # الأحدث أولاً (مثل الواجهة)
            parsed_entries.sort(key=lambda e: e.created_at, reverse=True)
            normalized[tooth_no] = parsed_entries

    return normalized


def _normalize_selected_tooth(selected_tooth: Optional[str]) -> Optional[str]:
    if selected_tooth is None:
        return None
    tooth_no = str(selected_tooth).strip()
    if not tooth_no:
        return None
    if tooth_no not in FDI_TEETH:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid selected tooth: {tooth_no}",
        )
    return tooth_no


async def _require_doctor_patient(*, patient_id: str, doctor_id: str) -> Patient:
    try:
        pid = OID(patient_id)
        did = OID(doctor_id)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid id format") from exc

    patient = await Patient.get(pid)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")
    if did not in (patient.doctor_ids or []):
        raise HTTPException(status_code=403, detail="Not your patient")
    return patient


async def get_dental_chart(
    *,
    patient_id: str,
    doctor_id: str,
) -> Optional[DentalChart]:
    """جلب مخطط الأسنان للطبيب الحالي. None إن لم يُنشأ بعد."""
    await _require_doctor_patient(patient_id=patient_id, doctor_id=doctor_id)
    return await DentalChart.find_one(
        DentalChart.patient_id == OID(patient_id),
        DentalChart.doctor_id == OID(doctor_id),
    )


async def upsert_dental_chart(
    *,
    patient_id: str,
    doctor_id: str,
    chart: Optional[Dict[str, Any]] = None,
    notes: Optional[Dict[str, Any]] = None,
    selected_tooth: Optional[str] = None,
) -> DentalChart:
    """إنشاء أو استبدال كامل لمخطط الأسنان (مطابق لـ _persistDentalData)."""
    await _require_doctor_patient(patient_id=patient_id, doctor_id=doctor_id)

    chart_data = _normalize_chart(chart)
    notes_data = _normalize_notes(notes)
    selected = _normalize_selected_tooth(selected_tooth)
    now = datetime.now(timezone.utc)

    existing = await DentalChart.find_one(
        DentalChart.patient_id == OID(patient_id),
        DentalChart.doctor_id == OID(doctor_id),
    )

    # مخطط فارغ بالكامل = حذف السجل إن وُجد (مثل الواجهة)
    if not chart_data and not notes_data:
        if existing:
            await existing.delete()
            # نُرجع كائناً فارغاً منطقياً بدون id محفوظ
            return DentalChart(
                patient_id=OID(patient_id),
                doctor_id=OID(doctor_id),
                chart={},
                notes={},
                selected_tooth=None,
                created_at=existing.created_at,
                updated_at=now,
            )
        return DentalChart(
            patient_id=OID(patient_id),
            doctor_id=OID(doctor_id),
            chart={},
            notes={},
            selected_tooth=None,
            created_at=now,
            updated_at=now,
        )

    if existing:
        existing.chart = chart_data
        existing.notes = notes_data
        existing.selected_tooth = selected
        existing.updated_at = now
        await existing.save()
        return existing

    doc = DentalChart(
        patient_id=OID(patient_id),
        doctor_id=OID(doctor_id),
        chart=chart_data,
        notes=notes_data,
        selected_tooth=selected,
        created_at=now,
        updated_at=now,
    )
    await doc.insert()
    return doc


async def patch_tooth(
    *,
    patient_id: str,
    doctor_id: str,
    tooth_no: str,
    statuses: Optional[List[str]] = None,
    notes: Optional[List[Any]] = None,
    clear: bool = False,
) -> DentalChart:
    """تحديث سن واحد دون استبدال المخطط بالكامل."""
    tooth_no = str(tooth_no).strip()
    if tooth_no not in FDI_TEETH:
        raise HTTPException(status_code=400, detail=f"Invalid FDI tooth number: {tooth_no}")

    await _require_doctor_patient(patient_id=patient_id, doctor_id=doctor_id)

    existing = await DentalChart.find_one(
        DentalChart.patient_id == OID(patient_id),
        DentalChart.doctor_id == OID(doctor_id),
    )
    now = datetime.now(timezone.utc)

    if not existing:
        existing = DentalChart(
            patient_id=OID(patient_id),
            doctor_id=OID(doctor_id),
            chart={},
            notes={},
            created_at=now,
            updated_at=now,
        )

    chart = dict(existing.chart or {})
    notes_map = dict(existing.notes or {})

    if clear:
        chart.pop(tooth_no, None)
        notes_map.pop(tooth_no, None)
    else:
        if statuses is not None:
            normalized = _normalize_chart({tooth_no: statuses})
            if tooth_no in normalized:
                chart[tooth_no] = normalized[tooth_no]
            else:
                chart.pop(tooth_no, None)
        if notes is not None:
            normalized_notes = _normalize_notes({tooth_no: notes})
            if tooth_no in normalized_notes:
                notes_map[tooth_no] = normalized_notes[tooth_no]
            else:
                notes_map.pop(tooth_no, None)

    existing.chart = chart
    existing.notes = notes_map
    existing.updated_at = now

    if not chart and not notes_map:
        if existing.id:
            await existing.delete()
        existing.chart = {}
        existing.notes = {}
        existing.selected_tooth = None
        return existing

    if existing.id:
        await existing.save()
    else:
        await existing.insert()
    return existing


async def delete_dental_chart(*, patient_id: str, doctor_id: str) -> bool:
    """حذف مخطط الأسنان بالكامل لهذا الطبيب."""
    await _require_doctor_patient(patient_id=patient_id, doctor_id=doctor_id)
    existing = await DentalChart.find_one(
        DentalChart.patient_id == OID(patient_id),
        DentalChart.doctor_id == OID(doctor_id),
    )
    if not existing:
        return False
    await existing.delete()
    return True
