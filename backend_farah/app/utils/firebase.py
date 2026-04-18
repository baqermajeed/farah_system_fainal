import json
from typing import List
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
except Exception as e:
    # In dev without credentials, we stay in no-op mode.
    _firebase_ready = False

async def send_firebase_message(tokens: List[str], title: str, body: str) -> None:
    """Send a multicast FCM message; no-op if Firebase not configured."""
    if not _firebase_ready or not tokens:
        print(f"[FCM:SKIP] title={title} body={body} tokens={len(tokens)}")
        return
    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        tokens=tokens,
    )
    response = messaging.send_multicast(message)
    print(f"[FCM] Sent: success={response.success_count} failure={response.failure_count}")
