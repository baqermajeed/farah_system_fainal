"""
Data migration for appointment system v2.

What it does:
1) Normalize appointment statuses to: pending|completed|cancelled
2) Backfill appointment kind: regular|implant
3) Normalize scheduled_at to UTC-aware datetimes
4) Repair implant stage -> appointment links using (patient_id, doctor_id, stage_name)

Run:
    python -m app.scripts.migrate_appointments_v2
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Optional

from app.database import init_db
from app.models import Appointment, ImplantStage


def _to_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _normalize_status(status: Optional[str]) -> str:
    value = (status or "pending").strip().lower()
    if value in {"scheduled", "late"}:
        return "pending"
    if value not in {"pending", "completed", "cancelled"}:
        return "pending"
    return value


def _determine_kind(appointment: Appointment) -> str:
    if getattr(appointment, "stage_name", None):
        return "implant"
    return "regular"


async def _migrate_appointments() -> tuple[int, int, int]:
    updated_status = 0
    updated_kind = 0
    updated_datetime = 0

    appointments = await Appointment.find_all().to_list()
    now = datetime.now(timezone.utc)

    for ap in appointments:
        changed = False

        normalized_status = _normalize_status(getattr(ap, "status", None))
        if ap.status != normalized_status:
            ap.status = normalized_status
            updated_status += 1
            changed = True

        kind = _determine_kind(ap)
        if getattr(ap, "kind", None) != kind:
            ap.kind = kind
            updated_kind += 1
            changed = True

        utc_scheduled = _to_utc(ap.scheduled_at)
        if ap.scheduled_at != utc_scheduled:
            ap.scheduled_at = utc_scheduled
            updated_datetime += 1
            changed = True

        if changed:
            ap.updated_at = now
            await ap.save()

    return updated_status, updated_kind, updated_datetime


async def _pick_stage_appointment(stage: ImplantStage) -> Optional[Appointment]:
    if stage.appointment_id:
        by_id = await Appointment.get(stage.appointment_id)
        if by_id:
            return by_id

    matches = (
        await Appointment.find(
            Appointment.patient_id == stage.patient_id,
            Appointment.doctor_id == stage.doctor_id,
            Appointment.stage_name == stage.stage_name,
        )
        .sort("-updated_at")
        .to_list()
    )
    if matches:
        return matches[0]
    return None


async def _repair_implant_stage_links() -> tuple[int, int]:
    linked_count = 0
    missing_count = 0

    stages = await ImplantStage.find_all().to_list()
    now = datetime.now(timezone.utc)

    for stage in stages:
        if stage.doctor_id is None:
            # Legacy records without doctor_id cannot be linked safely.
            missing_count += 1
            continue

        ap = await _pick_stage_appointment(stage)
        if not ap:
            missing_count += 1
            continue

        changed = False
        if stage.appointment_id != ap.id:
            stage.appointment_id = ap.id
            changed = True
            linked_count += 1

        utc_stage_date = _to_utc(stage.scheduled_at)
        if stage.scheduled_at != utc_stage_date:
            stage.scheduled_at = utc_stage_date
            changed = True

        if changed:
            stage.updated_at = now
            await stage.save()

    return linked_count, missing_count


async def run() -> None:
    await init_db()

    status_count, kind_count, dt_count = await _migrate_appointments()
    linked_count, missing_count = await _repair_implant_stage_links()

    print("=== Appointment v2 migration completed ===")
    print(f"Statuses normalized: {status_count}")
    print(f"Kind backfilled: {kind_count}")
    print(f"Datetime normalized to UTC: {dt_count}")
    print(f"Implant stages relinked: {linked_count}")
    print(f"Implant stages still missing appointment link: {missing_count}")


if __name__ == "__main__":
    asyncio.run(run())
