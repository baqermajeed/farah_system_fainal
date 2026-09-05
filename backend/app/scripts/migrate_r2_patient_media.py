"""
Migrate legacy R2 patient media paths to the new folder layout.

Old layout:
  patients/patient_{full_id}/{gallery|qr|profile|notes|appointments|chat_images}/{file}

New layout:
  patients/{name}_{last6}/{Gallery|QRcode|profile photo|not|appointment|chat}/{file}

Safety guarantees:
  - Default mode copies objects (never deletes old keys).
  - MongoDB URLs are updated only after a successful copy (or verified target exists).
  - --dry-run reports planned actions without writing.

Run:
  cd backend
  python -m app.scripts.migrate_r2_patient_media --dry-run
  python -m app.scripts.migrate_r2_patient_media
  python -m app.scripts.migrate_r2_patient_media --delete-old   # optional cleanup
"""

from __future__ import annotations

import argparse
import asyncio
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Optional
from urllib.parse import unquote

from beanie import PydanticObjectId as OID
from motor.motor_asyncio import AsyncIOMotorClient

from app.config import get_settings
from app.database import init_db
from app.models import (
    Appointment,
    ChatMessage,
    ChatRoom,
    GalleryImage,
    Patient,
    TreatmentNote,
    User,
)
from app.utils.r2_clinic import (
    PATIENT_MEDIA_FOLDERS,
    _get_r2_client,
    build_patient_dir_label,
    resolve_media_folder,
)

settings = get_settings()

OBJECT_ID_RE = re.compile(r"^[a-f0-9]{24}$", re.I)
NEW_MEDIA_FOLDERS = set(PATIENT_MEDIA_FOLDERS.values())
OLD_FOLDER_TO_INTERNAL: dict[str, str] = {
    "gallery": "gallery",
    "qr": "qr",
    "profile": "profile",
    "notes": "notes",
    "appointments": "appointments",
    "chat_images": "chat",
}


@dataclass
class MigrationStats:
    urls_scanned: int = 0
    already_new: int = 0
    skipped_unparseable: int = 0
    copied: int = 0
    copy_skipped_exists: int = 0
    copy_failed: int = 0
    db_updated: int = 0
    db_fields_updated: int = 0
    deleted_old: int = 0
    errors: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class UrlRef:
    collection: str
    doc_id: str
    field: str
    url: str
    index: int | None = None  # for list fields


def url_to_key(url: str) -> str | None:
    if not url or not isinstance(url, str):
        return None
    value = unquote(url.strip())
    if "/patients/" in value:
        return "patients/" + value.split("/patients/", 1)[1].split("?", 1)[0]
    if value.startswith("patients/"):
        return value.split("?", 1)[0]
    return None


def is_new_format_key(key: str) -> bool:
    parts = key.split("/")
    if len(parts) < 4 or parts[0] != "patients":
        return False
    return parts[2] in NEW_MEDIA_FOLDERS


def extract_storage_id_from_dir_label(dir_label: str) -> str | None:
    if dir_label.startswith("patient_"):
        candidate = dir_label[len("patient_") :]
        if OBJECT_ID_RE.match(candidate):
            return candidate
        return None

    suffix = dir_label.rsplit("_", 1)[-1]
    if OBJECT_ID_RE.match(suffix):
        return suffix
    if len(suffix) == 6 and re.fullmatch(r"[a-f0-9]{6}", suffix, re.I):
        return None
    return None


def parse_legacy_key(key: str) -> tuple[str, str, str] | None:
    """Return (storage_id, legacy_folder, filename) for old-format keys."""
    if is_new_format_key(key):
        return None

    parts = key.split("/")
    if len(parts) < 4 or parts[0] != "patients":
        return None

    dir_label, folder = parts[1], parts[2]
    filename = "/".join(parts[3:])
    if folder not in OLD_FOLDER_TO_INTERNAL:
        return None

    storage_id = extract_storage_id_from_dir_label(dir_label)
    if not storage_id:
        return None
    return storage_id, folder, filename


def rebuild_url(old_url: str, new_key: str) -> str:
    old_url = old_url.strip()
    if old_url.startswith("/media/"):
        return f"/media/{new_key}"
    if settings.R2_PUBLIC_BASE and settings.R2_PUBLIC_BASE.rstrip("/") in old_url:
        return f"{settings.R2_PUBLIC_BASE.rstrip('/')}/{new_key}"
    if "/patients/" in old_url:
        base = old_url.split("/patients/", 1)[0]
        return f"{base}/{new_key}"
    if settings.R2_PUBLIC_BASE:
        return f"{settings.R2_PUBLIC_BASE.rstrip('/')}/{new_key}"
    return f"/media/{new_key}"


def local_media_root() -> Path:
    return Path(__file__).resolve().parents[2] / "media"


async def resolve_patient_for_storage_id(storage_id: str) -> tuple[Patient, User | None]:
    oid = OID(storage_id)

    patient = await Patient.get(oid)
    if patient:
        user = await User.get(patient.user_id) if patient.user_id else None
        return patient, user

    user = await User.get(oid)
    if user:
        primary = await Patient.find_one(Patient.user_id == user.id, Patient.is_primary == True)
        if not primary:
            primary = await Patient.find_one(Patient.user_id == user.id)
        if primary:
            return primary, user

    room = await ChatRoom.get(oid)
    if room and room.patient_id:
        patient = await Patient.get(room.patient_id)
        if patient:
            user = await User.get(patient.user_id) if patient.user_id else None
            return patient, user

    raise ValueError(f"Could not resolve patient for storage id {storage_id}")


def patient_name_hint(patient: Patient, user: User | None) -> str | None:
    return patient.name or (user.name if user else None)


def extract_name_from_dir_label(dir_label: str, storage_id: str) -> str | None:
    if dir_label == f"patient_{storage_id}":
        return None
    suffix = f"_{storage_id}"
    if dir_label.endswith(suffix):
        name = dir_label[: -len(suffix)]
        return name.replace("_", " ") if name else None
    return None


async def build_new_key(
    *,
    storage_id: str,
    legacy_folder: str,
    filename: str,
    patient_cache: dict[str, tuple[Patient | None, User | None]],
    dir_label: str | None = None,
) -> str:
    name_hint: str | None = None
    patient_id_for_suffix = storage_id

    if storage_id not in patient_cache:
        try:
            patient_cache[storage_id] = await resolve_patient_for_storage_id(storage_id)
        except ValueError:
            patient_cache[storage_id] = (None, None)  # type: ignore[assignment]

    patient, user = patient_cache[storage_id]
    if patient:
        name_hint = patient_name_hint(patient, user)
        patient_id_for_suffix = str(patient.id)
    elif dir_label:
        name_hint = extract_name_from_dir_label(dir_label, storage_id)

    internal_folder = OLD_FOLDER_TO_INTERNAL[legacy_folder]
    dir_label_new = build_patient_dir_label(name_hint, patient_id_for_suffix)
    media_folder = resolve_media_folder(internal_folder)
    return f"patients/{dir_label_new}/{media_folder}/{filename}"


def object_exists_r2(client, bucket: str, key: str, cache: set[str] | None = None) -> bool:
    if cache is not None:
        return key in cache
    try:
        client.head_object(Bucket=bucket, Key=key)
        return True
    except Exception:
        return False


def list_r2_keys_under_patients(client, bucket: str) -> set[str]:
    keys: set[str] = set()
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix="patients/"):
        for item in page.get("Contents", []):
            key = item.get("Key")
            if key:
                keys.add(key)
    return keys


def list_local_keys_under_patients() -> set[str]:
    root = local_media_root() / "patients"
    if not root.exists():
        return set()
    keys: set[str] = set()
    for path in root.rglob("*"):
        if path.is_file():
            rel = path.relative_to(local_media_root()).as_posix()
            keys.add(rel)
    return keys


def copy_object_r2(client, bucket: str, old_key: str, new_key: str) -> None:
    client.copy_object(
        Bucket=bucket,
        Key=new_key,
        CopySource={"Bucket": bucket, "Key": old_key},
    )


def copy_object_local(old_key: str, new_key: str) -> None:
    src = local_media_root() / old_key
    dst = local_media_root() / new_key
    if not src.is_file():
        raise FileNotFoundError(f"Local source missing: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def plan_copy_stats(
    unique_migrations: list[tuple[str, str]],
    object_cache: set[str],
    stats: MigrationStats,
) -> set[str]:
    migrated_keys: set[str] = set()
    for old_key, new_key in unique_migrations:
        if old_key == new_key:
            migrated_keys.add(old_key)
            continue
        dst_exists = new_key in object_cache
        src_exists = old_key in object_cache
        if not src_exists and not dst_exists:
            stats.copy_failed += 1
            stats.errors.append(f"Missing source and target: {old_key}")
            continue
        if dst_exists:
            stats.copy_skipped_exists += 1
            migrated_keys.add(old_key)
            continue
        stats.copied += 1
        migrated_keys.add(old_key)
    return migrated_keys


async def run_copy_phase(
    unique_migrations: list[tuple[str, str]],
    object_cache: set[str],
    stats: MigrationStats,
) -> set[str]:
    migrated_keys: set[str] = set()
    client = _get_r2_client()
    bucket = settings.R2_BUCKET_NAME
    use_r2 = bool(client and bucket)

    for idx, (old_key, new_key) in enumerate(unique_migrations, start=1):
        if idx % 100 == 0 or idx == len(unique_migrations):
            print(f"Copy progress: {idx}/{len(unique_migrations)}", flush=True)
        if old_key == new_key:
            migrated_keys.add(old_key)
            continue

        if use_r2:
            if new_key in object_cache:
                stats.copy_skipped_exists += 1
                migrated_keys.add(old_key)
                continue
            if old_key not in object_cache:
                stats.copy_failed += 1
                stats.errors.append(f"Source missing in R2: {old_key}")
                continue
            copy_object_r2(client, bucket, old_key, new_key)
            object_cache.add(new_key)
            stats.copied += 1
            migrated_keys.add(old_key)
            continue

        dst = local_media_root() / new_key
        src = local_media_root() / old_key
        if dst.is_file():
            stats.copy_skipped_exists += 1
            object_cache.add(new_key)
            migrated_keys.add(old_key)
            continue
        if not src.is_file():
            stats.copy_failed += 1
            stats.errors.append(f"Missing locally: {old_key}")
            continue
        copy_object_local(old_key, new_key)
        object_cache.add(new_key)
        stats.copied += 1
        migrated_keys.add(old_key)

    return migrated_keys


async def delete_old_object(
    old_key: str,
    new_key: str,
    dry_run: bool,
    stats: MigrationStats,
    object_cache: set[str],
) -> None:
    if old_key == new_key:
        return

    client = _get_r2_client()
    bucket = settings.R2_BUCKET_NAME
    use_r2 = bool(client and bucket)

    if use_r2:
        if dry_run:
            if object_exists_r2(client, bucket, old_key, object_cache):
                stats.deleted_old += 1
            return
        if object_exists_r2(client, bucket, old_key, object_cache):
            client.delete_object(Bucket=bucket, Key=old_key)
            object_cache.discard(old_key)
            stats.deleted_old += 1
        return

    src = local_media_root() / old_key
    if dry_run:
        if src.is_file():
            stats.deleted_old += 1
        return
    if src.is_file():
        src.unlink()
        object_cache.discard(old_key)
        stats.deleted_old += 1


async def collect_url_refs() -> list[UrlRef]:
    refs: list[UrlRef] = []

    for patient in await Patient.find_all().to_list():
        pid = str(patient.id)
        if patient.imageUrl:
            refs.append(UrlRef("patients", pid, "imageUrl", patient.imageUrl))
        if patient.qr_image_path:
            refs.append(UrlRef("patients", pid, "qr_image_path", patient.qr_image_path))

    for user in await User.find_all().to_list():
        if user.imageUrl:
            refs.append(UrlRef("users", str(user.id), "imageUrl", user.imageUrl))

    for gi in await GalleryImage.find_all().to_list():
        refs.append(UrlRef("gallery_images", str(gi.id), "image_path", gi.image_path))

    for note in await TreatmentNote.find_all().to_list():
        nid = str(note.id)
        if note.image_path:
            refs.append(UrlRef("treatment_notes", nid, "image_path", note.image_path))
        for idx, path in enumerate(note.image_paths or []):
            refs.append(UrlRef("treatment_notes", nid, "image_paths", path, index=idx))

    for ap in await Appointment.find_all().to_list():
        aid = str(ap.id)
        if ap.image_path:
            refs.append(UrlRef("appointments", aid, "image_path", ap.image_path))
        for idx, path in enumerate(ap.image_paths or []):
            refs.append(UrlRef("appointments", aid, "image_paths", path, index=idx))

    for msg in await ChatMessage.find_all().to_list():
        if msg.imageUrl:
            refs.append(UrlRef("chat_messages", str(msg.id), "imageUrl", msg.imageUrl))

    return refs


async def apply_db_updates(
    refs: list[UrlRef],
    url_map: dict[str, str],
    migrated_keys: set[str],
    dry_run: bool,
    stats: MigrationStats,
) -> int:
    pending: dict[tuple[str, str], list[tuple[UrlRef, str]]] = {}
    for ref in refs:
        new_url = url_map.get(ref.url)
        if not new_url or new_url == ref.url:
            continue
        old_key = url_to_key(ref.url)
        if old_key and old_key not in migrated_keys:
            continue
        pending.setdefault((ref.collection, ref.doc_id), []).append((ref, new_url))

    if dry_run:
        stats.db_fields_updated = sum(len(items) for items in pending.values())
        return len(pending)

    # Use raw Motor updates to avoid Beanie `.save()` side effects that can
    # materialize `client_operation_id=None` and trip unique sparse indexes.
    client = AsyncIOMotorClient(settings.MONGODB_URI)
    db_name = settings.MONGODB_URI.rsplit("/", 1)[-1].split("?", 1)[0] or "clinic_db"
    db = client[db_name]

    updated_docs = 0
    for (collection, doc_id), items in pending.items():
        oid = OID(doc_id)
        set_ops: dict[str, Any] = {}
        for ref, new_url in items:
            if collection in {"patients", "users"}:
                set_ops[ref.field] = new_url
            elif collection == "gallery_images":
                set_ops["image_path"] = new_url
            elif collection in {"treatment_notes", "appointments"}:
                if ref.field == "image_path":
                    set_ops["image_path"] = new_url
                elif ref.field == "image_paths" and ref.index is not None:
                    set_ops[f"image_paths.{ref.index}"] = new_url
            elif collection == "chat_messages":
                set_ops["imageUrl"] = new_url

        if not set_ops:
            continue

        result = await db[collection].update_one({"_id": oid}, {"$set": set_ops})
        if result.matched_count == 0:
            stats.errors.append(f"Mongo doc missing for update: {collection}:{doc_id}")
            continue

        updated_docs += 1
        stats.db_fields_updated += len(items)

    client.close()
    return updated_docs


async def run_migration(*, dry_run: bool, delete_old: bool) -> MigrationStats:
    print("Connecting to database...", flush=True)
    await init_db()
    stats = MigrationStats()

    print("Collecting image URLs from MongoDB...", flush=True)
    refs = await collect_url_refs()
    stats.urls_scanned = len(refs)
    print(f"Found {stats.urls_scanned} URL references.", flush=True)

    client = _get_r2_client()
    bucket = settings.R2_BUCKET_NAME
    if client and bucket:
        print("Listing existing R2 objects under patients/ ...", flush=True)
        object_cache = list_r2_keys_under_patients(client, bucket)
        print(f"Indexed {len(object_cache)} R2 objects.", flush=True)
    else:
        print("R2 not configured; using local media directory.", flush=True)
        object_cache = list_local_keys_under_patients()
        print(f"Indexed {len(object_cache)} local media files.", flush=True)

    patient_cache: dict[str, tuple[Patient | None, User | None]] = {}
    url_map: dict[str, str] = {}
    key_plan: dict[str, str] = {}

    print("Planning migrations...", flush=True)
    for ref in refs:
        key = url_to_key(ref.url)
        if not key:
            stats.skipped_unparseable += 1
            continue

        if is_new_format_key(key):
            stats.already_new += 1
            continue

        parsed = parse_legacy_key(key)
        if not parsed:
            stats.skipped_unparseable += 1
            stats.errors.append(f"Unparseable legacy key: {key}")
            continue

        storage_id, legacy_folder, filename = parsed
        dir_label = key.split("/")[1]
        try:
            new_key = await build_new_key(
                storage_id=storage_id,
                legacy_folder=legacy_folder,
                filename=filename,
                patient_cache=patient_cache,
                dir_label=dir_label,
            )
        except ValueError as exc:
            stats.skipped_unparseable += 1
            stats.errors.append(f"{key}: {exc}")
            continue

        key_plan[key] = new_key
        url_map[ref.url] = rebuild_url(ref.url, new_key)

    unique_migrations = sorted(key_plan.items())
    print(f"Planned {len(unique_migrations)} unique object migrations.", flush=True)

    if dry_run:
        print("Simulating copy phase...", flush=True)
        migrated_keys = plan_copy_stats(unique_migrations, object_cache, stats)
    else:
        migrated_keys = await run_copy_phase(unique_migrations, object_cache, stats)

    print("Updating MongoDB URL references...", flush=True)
    stats.db_updated = await apply_db_updates(refs, url_map, migrated_keys, dry_run, stats)

    if delete_old:
        print("Deleting legacy objects...", flush=True)
        for old_key, new_key in unique_migrations:
            if old_key in migrated_keys:
                await delete_old_object(
                    old_key,
                    new_key,
                    dry_run=dry_run,
                    stats=stats,
                    object_cache=object_cache,
                )

    return stats


def print_report(stats: MigrationStats, *, dry_run: bool) -> None:
    mode = "DRY RUN" if dry_run else "LIVE"
    print(f"=== R2 patient media migration ({mode}) ===")
    print(f"URLs scanned:              {stats.urls_scanned}")
    print(f"Already new format:        {stats.already_new}")
    print(f"Skipped / unparseable:     {stats.skipped_unparseable}")
    print(f"Objects copied:            {stats.copied}")
    print(f"Copy skipped (exists):     {stats.copy_skipped_exists}")
    print(f"Copy failed:               {stats.copy_failed}")
    print(f"Documents updated:         {stats.db_updated}")
    print(f"DB fields updated:         {stats.db_fields_updated}")
    print(f"Old objects deleted:       {stats.deleted_old}")
    if stats.errors:
        print("\nIssues:")
        for err in stats.errors[:50]:
            print(f"  - {err}")
        if len(stats.errors) > 50:
            print(f"  ... and {len(stats.errors) - 50} more")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Migrate legacy R2 patient media paths.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report actions without copying files or updating MongoDB.",
    )
    parser.add_argument(
        "--delete-old",
        action="store_true",
        help="Delete legacy R2 keys after successful migration (off by default).",
    )
    return parser.parse_args()


async def run() -> None:
    args = parse_args()
    stats = await run_migration(dry_run=args.dry_run, delete_old=args.delete_old)
    print_report(stats, dry_run=args.dry_run)


if __name__ == "__main__":
    asyncio.run(run())
