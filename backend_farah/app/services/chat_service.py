import asyncio
from typing import Dict, Set
from fastapi import WebSocket

class ConnectionManager:
    """In-memory WebSocket connection manager per room.
    - For production scaling, replace with Redis PubSub or similar.
    """
    def __init__(self) -> None:
        """تهيئة المُدير مع خريطة غرف ومزلاج لحماية الوصول المتزامن."""
        self.rooms: Dict[str, Set[WebSocket]] = {}
        self.lock = asyncio.Lock()

    async def connect(self, room: str, websocket: WebSocket) -> None:
        """قبول الإتصال وإضافته إلى الغرفة المحددة."""
        await websocket.accept()
        async with self.lock:
            self.rooms.setdefault(room, set()).add(websocket)

    async def disconnect(self, room: str, websocket: WebSocket) -> None:
        """إزالة الإتصال من الغرفة وتنظيف الغرفة إذا أصبحت فارغة."""
        async with self.lock:
            if room in self.rooms and websocket in self.rooms[room]:
                self.rooms[room].remove(websocket)
                if not self.rooms[room]:
                    self.rooms.pop(room, None)

    async def broadcast(self, room: str, message: dict) -> None:
        """Send a JSON message to all sockets in the room."""
        conns = list(self.rooms.get(room, set()))
        for ws in conns:
            try:
                await ws.send_json(message)
            except Exception:
                pass
