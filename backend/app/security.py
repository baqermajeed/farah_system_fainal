from datetime import datetime, timedelta, timezone
from typing import List, Optional, Callable

from beanie import PydanticObjectId as OID
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from passlib.context import CryptContext

from app.config import get_settings
from app.constants import Role
from app.models.user import User

settings = get_settings()

# هذا الـ tokenUrl يستخدم فقط في واجهة التوثيق (Swagger)
# ويمكن للعميل استخدام /auth/verify-otp (للمرضى) أو /auth/staff-login (للطاقم).
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/staff-login")

# ------------------------ Password hashing helpers ------------------------

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """تشفير كلمة المرور باستخدام bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str | None) -> bool:
    """التحقق من كلمة المرور، يرجع False إذا لم يوجد hash."""
    if not hashed_password:
        return False
    return pwd_context.verify(plain_password, hashed_password)


# ------------------------ JWT helpers ------------------------


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a signed JWT access token (short-lived - 1 hour by default)."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire, "type": "access"})  # إضافة type للتمييز
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a signed JWT refresh token (long-lived - 30 days by default)."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    )
    to_encode.update({"exp": expire, "type": "refresh"})  # إضافة type للتمييز
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str, token_type: str = "access") -> dict:
    """Decode JWT token and verify its type."""
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
        )
        # التحقق من نوع الـ token
        if payload.get("type") != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token type. Expected {token_type}",
            )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


async def get_current_user(
    token: str = Depends(oauth2_scheme),
) -> User:
    """Decode JWT access token and fetch current user from MongoDB.
    Raises 401 if token invalid, expired, or user not found.
    Only accepts access tokens, not refresh tokens.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # استخدام decode_token للتحقق من نوع الـ token
        payload = decode_token(token, token_type="access")
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except HTTPException:
        raise
    except Exception:
        raise credentials_exception

    try:
        user = await User.get(OID(user_id))
    except Exception:
        user = None
    if not user:
        raise credentials_exception
    return user


# ------------------------ RBAC helpers ------------------------


def require_roles(allowed: List[Role]) -> Callable:
    """FastAPI dependency factory to enforce role-based access.
    Usage: Depends(require_roles([Role.ADMIN, Role.DOCTOR]))
    """

    async def checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user

    return checker
