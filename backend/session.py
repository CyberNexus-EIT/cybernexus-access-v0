
"""
CyberNexus Access
Authentication and Session Management
Version: 0.0.1
"""

import os
import logging
import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, Literal

from fastapi import APIRouter, HTTPException, Depends, Request, Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from passlib.context import CryptContext


# Configuration

logger = logging.getLogger("cybernexus.access.session")

router = APIRouter()

security = HTTPBearer(auto_error=False)

pwd_context = CryptContext(
    schemes=["argon2"],
    deprecated="auto"
)

SESSION_SECRET = os.getenv("SESSION_SECRET")

SESSION_DURATION = int(
    os.getenv("SESSION_DURATION_HOURS", "24")
)

COOKIE_NAME = "cybernexus_session"

COOKIE_SECURE = (
    os.getenv("COOKIE_SECURE", "true").lower() == "true"
)

if not SESSION_SECRET or len(SESSION_SECRET) < 32:
    if os.getenv("APP_ENV", "development") == "production":
        raise RuntimeError(
            "A SESSION_SECRET of at least 32 characters is required."
        )

    logger.warning("Using temporary development session configuration.")
    SESSION_SECRET = secrets.token_urlsafe(48)


# Data Models

class RegisterRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    email: EmailStr
    password: str = Field(min_length=12, max_length=128)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class SessionResponse(BaseModel):
    success: bool
    message: str
    user_id: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None


# Temporary Database Interface
# Replace with Supabase PostgreSQL integration.

class SessionRepository:
    async def get_user_by_email(self, email: str):
        raise NotImplementedError(
            "Connect this repository to Supabase PostgreSQL."
        )

    async def create_user(
        self,
        email: str,
        password_hash: str
    ):
        raise NotImplementedError(
            "Implement secure user registration in Supabase."
        )

    async def create_session(
        self,
        user_id: str,
        token_hash: str,
        expires_at: datetime
    ):
        raise NotImplementedError(
            "Implement persistent session storage."
        )

    async def get_session(self, token_hash: str):
        raise NotImplementedError(
            "Implement session lookup."
        )

    async def revoke_session(self, token_hash: str):
        raise NotImplementedError(
            "Implement session revocation."
        )


repository = SessionRepository()


# Security Utilities

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(
    password: str,
    password_hash: str
) -> bool:
    return pwd_context.verify(password, password_hash)


def hash_session_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_session_token() -> str:
    return secrets.token_urlsafe(48)


def create_session_expiration() -> datetime:
    return datetime.now(timezone.utc) + timedelta(
        hours=SESSION_DURATION
    )


# Session Cookie

def set_session_cookie(
    response: Response,
    token: str
):
    response.set_cookie(
        key=COOKIE_NAME,
        value=token,
        httponly=True,
        secure=COOKIE_SECURE,
        samesite="lax",
        max_age=SESSION_DURATION * 3600,
        path="/"
    )


def clear_session_cookie(response: Response):
    response.delete_cookie(
        key=COOKIE_NAME,
        httponly=True,
        secure=COOKIE_SECURE,
        samesite="lax",
        path="/"
    )


# Session Authentication

async def get_current_session(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    token = request.cookies.get(COOKIE_NAME)

    if not token and credentials:
        token = credentials.credentials

    if not token:
        raise HTTPException(
            status_code=401,
            detail="Authentication required."
        )

    token_hash = hash_session_token(token)

    session = await repository.get_session(token_hash)

    if not session:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired session."
        )

    expires_at = session["expires_at"]

    if expires_at <= datetime.now(timezone.utc):
        await repository.revoke_session(token_hash)

        raise HTTPException(
            status_code=401,
            detail="Session expired."
        )

    return {
        "user_id": session["user_id"],
        "email": session["email"],
        "role": session["role"]
    }


# Registration

@router.post(
    "/register",
    response_model=SessionResponse,
    status_code=201
)
async def register(data: RegisterRequest):
    email = str(data.email).lower()

    existing_user = await repository.get_user_by_email(email)

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="An account with this email already exists."
        )

    password_hash = hash_password(data.password)

    user = await repository.create_user(
        email=email,
        password_hash=password_hash
    )

    return SessionResponse(
        success=True,
        message="Account registration submitted successfully.",
        user_id=str(user["id"]),
        email=email,
        role=user.get("role", "User")
    )


# Login

@router.post(
    "/login",
    response_model=SessionResponse
)
async def login(
    data: LoginRequest,
    request: Request,
    response: Response
):
    email = str(data.email).lower()

    user = await repository.get_user_by_email(email)

    if not user or not verify_password(
        data.password,
        user["password_hash"]
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password."
        )

    if user.get("status") != "Approved":
        raise HTTPException(
            status_code=403,
            detail="Account is not approved for access."
        )

    token = generate_session_token()
    token_hash = hash_session_token(token)
    expires_at = create_session_expiration()

    await repository.create_session(
        user_id=str(user["id"]),
        token_hash=token_hash,
        expires_at=expires_at
    )

    set_session_cookie(response, token)

    return SessionResponse(
        success=True,
        message="Login successful.",
        user_id=str(user["id"]),
        email=email,
        role=user["role"]
    )


# Current Session

@router.get(
    "/session",
    response_model=SessionResponse
)
async def current_session(
    user=Depends(get_current_session)
):
    return SessionResponse(
        success=True,
        message="Active session.",
        user_id=user["user_id"],
        email=user["email"],
        role=user["role"]
    )


# Logout

@router.post("/logout")
async def logout(
    response: Response,
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    token = request.cookies.get(COOKIE_NAME)

    if not token and credentials:
        token = credentials.credentials

    if token:
        await repository.revoke_session(
            hash_session_token(token)
        )

    clear_session_cookie(response)

    return {
        "success": True,
        "message": "Logout successful."
    }
