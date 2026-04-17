# backend/app/api/v1/endpoints/auth.py
import pyotp
import secrets
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import jwt
import logging

from ....core.config import settings
from ....core.database import get_db
from ....core.security import create_access_token, create_refresh_token, get_current_user
from ....models.user import User
from ....schemas.auth import (
    SendOtpRequest, VerifyOtpRequest, RegisterRequest,
    AuthResponse, UserResponse
)
from ....services.sms_service import SMSService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])

# In-memory OTP store (use Redis in production)
_otp_store: dict = {}


@router.post("/send-otp")
async def send_otp(
    request: SendOtpRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    """Send OTP to phone number."""
    phone = f"{request.country_code}{request.phone}".replace("+", "").replace(" ", "")

    # Generate 6-digit OTP
    otp = secrets.randbelow(900000) + 100000
    otp_str = str(otp)

    # Store OTP with 10-minute expiry
    _otp_store[phone] = {
        "otp": otp_str,
        "expires_at": datetime.utcnow() + timedelta(minutes=10),
        "attempts": 0,
    }

    # Send via SMS (Twilio/MSG91)
    background_tasks.add_task(
        SMSService.send_otp,
        phone=f"+{phone}",
        otp=otp_str,
    )

    # In development, return OTP in response (REMOVE IN PRODUCTION)
    if settings.DEBUG:
        return {"message": "OTP sent", "debug_otp": otp_str}

    return {"message": "OTP sent successfully"}


@router.post("/verify-otp", response_model=AuthResponse)
async def verify_otp(
    request: VerifyOtpRequest,
    db: AsyncSession = Depends(get_db),
):
    """Verify OTP and return JWT tokens."""
    phone = f"{request.country_code or '91'}{request.phone}".replace("+", "").replace(" ", "")

    # Check OTP
    stored = _otp_store.get(phone)
    if not stored:
        raise HTTPException(status_code=400, detail="OTP not found. Please request a new one.")

    if datetime.utcnow() > stored["expires_at"]:
        del _otp_store[phone]
        raise HTTPException(status_code=400, detail="OTP expired. Please request a new one.")

    stored["attempts"] += 1
    if stored["attempts"] > 5:
        del _otp_store[phone]
        raise HTTPException(status_code=429, detail="Too many attempts. Please request a new OTP.")

    if stored["otp"] != request.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    del _otp_store[phone]  # Clear after successful verification

    # Find or create user
    stmt = select(User).where(User.phone == phone)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        # Auto-create user with phone
        username = f"user_{phone[-6:]}"  # Simple default username
        # Ensure unique username
        count = 0
        base_username = username
        while True:
            existing = await db.execute(select(User).where(User.username == username))
            if not existing.scalar_one_or_none():
                break
            count += 1
            username = f"{base_username}_{count}"

        user = User(
            phone=phone,
            username=username,
            phone_country_code=request.country_code or "91",
            is_verified=True,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    else:
        user.is_verified = True
        user.last_seen_at = datetime.utcnow()
        await db.commit()

    # Generate tokens
    access_token = create_access_token({"sub": str(user.id), "username": user.username})
    refresh_token = create_refresh_token({"sub": str(user.id)})

    return AuthResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=UserResponse(
            id=str(user.id),
            username=user.username,
            phone=user.phone,
            email=user.email,
            full_name=user.full_name,
            avatar_url=user.avatar_url,
            subscription_tier=user.subscription_tier.value,
            is_verified=user.is_verified,
            created_at=user.created_at.isoformat(),
        )
    )


@router.post("/register")
async def register(
    request: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """Register a new user (before OTP verification)."""
    # Check username availability
    stmt = select(User).where(User.username == request.username)
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Username already taken")

    # Check phone
    phone = request.phone.replace("+", "").replace(" ", "")
    stmt = select(User).where(User.phone == phone)
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Phone already registered")

    return {"message": "Registration details saved. Please verify your phone."}


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=str(current_user.id),
        username=current_user.username,
        phone=current_user.phone,
        email=current_user.email,
        full_name=current_user.full_name,
        avatar_url=current_user.avatar_url,
        subscription_tier=current_user.subscription_tier.value,
        is_verified=current_user.is_verified,
        created_at=current_user.created_at.isoformat(),
    )


@router.post("/refresh")
async def refresh_token(
    request: dict,
    db: AsyncSession = Depends(get_db),
):
    """Refresh access token using refresh token."""
    token = request.get("refresh_token")
    if not token:
        raise HTTPException(status_code=400, detail="Refresh token required")

    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Refresh token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    # Fetch user
    from uuid import UUID
    stmt = select(User).where(User.id == UUID(user_id))
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    access_token = create_access_token({"sub": str(user.id), "username": user.username})

    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/logout")
async def logout(current_user: User = Depends(get_current_user)):
    """Logout user (client should delete tokens)."""
    return {"message": "Logged out successfully"}


@router.get("/check-username/{username}")
async def check_username(username: str, db: AsyncSession = Depends(get_db)):
    """Check if username is available."""
    if len(username) < 3 or len(username) > 30:
        return {"available": False, "reason": "Username must be 3-30 characters"}

    import re
    if not re.match(r'^[a-zA-Z0-9_\.]+$', username):
        return {"available": False, "reason": "Only letters, numbers, _ and . allowed"}

    stmt = select(User).where(User.username == username)
    result = await db.execute(stmt)
    exists = result.scalar_one_or_none() is not None

    return {"available": not exists}
