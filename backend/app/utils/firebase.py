from __future__ import annotations

import os
from pathlib import Path
from typing import List, Optional, Dict

from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger("firebase")

settings = get_settings()

# Channel id must match the Flutter local notifications channel.
FCM_ANDROID_CHANNEL_ID = "farah_high_importance"

_firebase_ready = False
_init_error: str | None = None


def _candidate_credential_paths() -> list[Path]:
    backend_root = Path(__file__).resolve().parents[2]
    candidates: list[Path] = []

    for raw in (
        settings.FIREBASE_CREDENTIALS_FILE,
        os.getenv("FIREBASE_CREDENTIALS_FILE"),
        os.getenv("GOOGLE_APPLICATION_CREDENTIALS"),
    ):
        if raw:
            candidates.append(Path(raw))

    candidates.extend(
        [
            backend_root / "farah-notification-firebase-adminsdk-fbsvc-8bdffc9376.json",
            backend_root / "firebase-credentials.json",
            backend_root / "secrets" / "firebase-credentials.json",
            backend_root / "farah-notification-firebase-adminsdk.json",
        ]
    )

    seen: set[str] = set()
    unique: list[Path] = []
    for path in candidates:
        key = str(path)
        if key in seen:
            continue
        seen.add(key)
        unique.append(path)
    return unique


def _init_firebase() -> None:
    global _firebase_ready, _init_error

    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            _firebase_ready = True
            _init_error = None
            logger.info("Firebase Admin already initialized")
            return

        cred_path: Path | None = None
        for path in _candidate_credential_paths():
            if path.is_file():
                cred_path = path
                break

        if cred_path is None:
            _init_error = (
                "Firebase credentials file not found. Set FIREBASE_CREDENTIALS_FILE "
                "in .env to your service-account JSON (Firebase Console → "
                "Project settings → Service accounts → Generate new private key)."
            )
            logger.warning("[FCM] %s", _init_error)
            return

        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
        _firebase_ready = True
        _init_error = None
        logger.info("[FCM] Firebase Admin initialized from %s", cred_path)
    except Exception as exc:
        _firebase_ready = False
        _init_error = str(exc)
        logger.error("[FCM] Firebase init failed: %s", exc)


_init_firebase()


def is_firebase_ready() -> bool:
    return _firebase_ready


def firebase_init_error() -> str | None:
    return _init_error


async def send_firebase_message(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> int:
    """Send a multicast FCM message. Returns number of successful deliveries."""
    if not tokens:
        logger.warning("[FCM:SKIP] No device tokens for title=%s", title)
        return 0

    if not _firebase_ready:
        logger.warning(
            "[FCM:SKIP] Firebase not configured — push not sent. title=%s tokens=%s error=%s",
            title,
            len(tokens),
            _init_error,
        )
        return 0

    from firebase_admin import messaging

    payload = {k: str(v) for k, v in (data or {}).items() if v is not None}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=payload or None,
        tokens=tokens,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id=FCM_ANDROID_CHANNEL_ID,
                sound="default",
                priority="high",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", badge=1),
            ),
        ),
    )

    try:
        response = messaging.send_each_for_multicast(message)
        logger.info(
            "[FCM] Sent title=%s success=%s failure=%s",
            title,
            response.success_count,
            response.failure_count,
        )
        if response.failure_count:
            for idx, send_response in enumerate(response.responses):
                if not send_response.success:
                    logger.warning(
                        "[FCM] Token[%s] failed: %s",
                        idx,
                        send_response.exception,
                    )
        return response.success_count
    except Exception as exc:
        logger.error("[FCM] Send failed title=%s error=%s", title, exc)
        return 0
