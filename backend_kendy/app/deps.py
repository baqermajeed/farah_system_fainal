from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.security import get_current_user

# Common dependencies used across routers
CurrentDB = Depends(get_db)
CurrentUser = Depends(get_current_user)
