from typing import List, Optional, Dict
from app.config import get_settings

settings = get_settings()

# Lazy import to avoid heavy deps if not configured
_firebase_ready = False
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    if settings.FIREBASE_CREDENTIALS_FILE:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_FILE)
        firebase_admin.initialize_app(cred)
        _firebase_ready = True
except Exception:
    # In dev without credentials, we stay in no-op mode.
    _firebase_ready = False


async def send_firebase_message(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
) -> None:
    """Send a multicast FCM message; no-op if Firebase not configured."""
    if not _firebase_ready or not tokens:
        print(f"[FCM:SKIP] title={title} body={body} tokens={len(tokens)} data={data}")
        return

    # FCM data payload values must be strings
    payload = {k: str(v) for k, v in (data or {}).items() if v is not None}

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=payload or None,
        tokens=tokens,
    )
    response = messaging.send_multicast(message)
    print(f"[FCM] Sent: success={response.success_count} failure={response.failure_count}")
