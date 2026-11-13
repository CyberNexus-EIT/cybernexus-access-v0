"""
CyberNexus Access - Authentication and Session Management.
PostgreSQL-backed implementation for the hosted application.
"""
import os
import logging
import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Request, Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from passlib.context import CryptContext

from backend.database import get_pool

logger = logging.getLogger("cybernexus.access.session")
router = APIRouter()
security = HTTPBearer(auto_error=False)
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

SESSION_DURATION = int(os.getenv("SESSION_DURATION_HOURS", "24"))
COOKIE_NAME = "cybernexus_session"
COOKIE_SECURE = os.getenv("COOKIE_SECURE", "true").lower() == "true"
SESSION_SECRET = os.getenv("SESSION_SECRET")
if not SESSION_SECRET or len(SESSION_SECRET) < 32:
    if os.getenv("APP_ENV", "development") == "production":
        raise RuntimeError("A SESSION_SECRET of at least 32 characters is required.")
    SESSION_SECRET = secrets.token_urlsafe(48)

class RegisterRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    full_name: str = Field(min_length=2, max_length=150)
    username: str = Field(min_length=3, max_length=32, pattern=r"^[A-Za-z0-9._-]+$")
    phone: str = Field(min_length=7, max_length=20)
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)

class LoginRequest(BaseModel):
    login_identifier: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=1, max_length=128)

class SessionResponse(BaseModel):
    success: bool
    message: str
    authenticated: bool = False
    user: Optional[dict] = None
    user_id: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)

def hash_session_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()

def generate_session_token() -> str:
    return secrets.token_urlsafe(48)

def create_session_expiration() -> datetime:
    return datetime.now(timezone.utc) + timedelta(hours=SESSION_DURATION)

def set_session_cookie(response: Response, token: str):
    response.set_cookie(
        key=COOKIE_NAME, value=token, httponly=True, secure=COOKIE_SECURE,
        samesite="lax", max_age=SESSION_DURATION * 3600, path="/"
    )

def clear_session_cookie(response: Response):
    response.delete_cookie(
        key=COOKIE_NAME, httponly=True, secure=COOKIE_SECURE,
        samesite="lax", path="/"
    )

class SessionRepository:
    async def get_user_by_identifier(self, identifier: str):
        pool = get_pool()
        async with pool.acquire() as conn:
            return await conn.fetchrow("""
                SELECT u.id, u.email, u.password_hash, u.account_status,
                       r.name AS role
                FROM users u
                LEFT JOIN user_roles ur ON ur.user_id = u.id
                LEFT JOIN roles r ON r.id = ur.role_id
                WHERE u.email_normalized = lower(btrim($1))
                   OR lower(u.username) = lower(btrim($1))
                   OR u.phone = btrim($1)
                LIMIT 1
            """, identifier)

    async def get_user_by_email(self, email: str):
        return await self.get_user_by_identifier(email)

    async def create_user(self, full_name: str, username: str, phone: str, email: str, password_hash: str):
        pool = get_pool()
        async with pool.acquire() as conn:
            async with conn.transaction():
                user = await conn.fetchrow("""
                    INSERT INTO users (full_name, username, phone, email, password_hash)
                    VALUES ($1, $2, $3, $4, $5)
                    RETURNING id, email, account_status
                """, full_name, username, phone, email, password_hash)
                role_id = await conn.fetchval("SELECT id FROM roles WHERE name = 'User'")
                await conn.execute(
                    "INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2)",
                    user["id"], role_id
                )
                await conn.execute(
                    "INSERT INTO account_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING",
                    user["id"]
                )
                return user

    async def create_session(self, user_id, token_hash: str, expires_at: datetime, request: Request):
        pool = get_pool()
        async with pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO sessions (user_id, token_hash, ip_address, user_agent, expires_at)
                VALUES ($1, $2, $3::inet, $4, $5)
            """, user_id, token_hash, request.client.host if request.client else None,
                 request.headers.get("user-agent", "")[:1000], expires_at)

    async def get_session(self, token_hash: str):
        pool = get_pool()
        async with pool.acquire() as conn:
            return await conn.fetchrow("""
                SELECT s.user_id, s.expires_at, u.email, r.name AS role
                FROM sessions s
                JOIN users u ON u.id = s.user_id
                LEFT JOIN user_roles ur ON ur.user_id = u.id
                LEFT JOIN roles r ON r.id = ur.role_id
                WHERE s.token_hash = $1 AND s.revoked_at IS NULL
                  AND s.expires_at > NOW() AND u.account_status = 'approved'
                LIMIT 1
            """, token_hash)

    async def revoke_session(self, token_hash: str):
        pool = get_pool()
        async with pool.acquire() as conn:
            await conn.execute("""
                UPDATE sessions SET revoked_at = NOW()
                WHERE token_hash = $1 AND revoked_at IS NULL
            """, token_hash)

repository = SessionRepository()

async def get_current_session(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
):
    token = request.cookies.get(COOKIE_NAME)
    if not token and credentials:
        token = credentials.credentials
    if not token:
        raise HTTPException(status_code=401, detail="Authentication required.")
    session = await repository.get_session(hash_session_token(token))
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session.")
    return {
        "user_id": str(session["user_id"]),
        "email": session["email"],
        "role": (session["role"] or "User").lower()
    }

@router.post("/register", response_model=SessionResponse, status_code=201)
async def register(data: RegisterRequest):
    email = str(data.email).lower()
    try:
        user = await repository.create_user(
            data.full_name.strip(), data.username.strip(), data.phone.strip(),
            email, hash_password(data.password)
        )
    except Exception as exc:
        if "unique" in str(exc).lower():
            raise HTTPException(status_code=409, detail="Email, username, or phone number is already registered.")
        raise
    return SessionResponse(
        success=True, message="Registration submitted. Wait for administrator approval.",
        user_id=str(user["id"]), email=email, role="user"
    )

@router.post("/login", response_model=SessionResponse)
async def login(data: LoginRequest, request: Request, response: Response):
    user = await repository.get_user_by_identifier(data.login_identifier)
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid login identifier or password.")
    if user["account_status"] != "approved":
        raise HTTPException(status_code=403, detail="Account is pending approval or is not permitted to sign in.")
    token = generate_session_token()
    await repository.create_session(
        user["id"], hash_session_token(token), create_session_expiration(), request
    )
    await _update_last_login(user["id"])
    set_session_cookie(response, token)
    role = (user["role"] or "User").lower()
    return SessionResponse(
        success=True, message="Login successful.", authenticated=True,
        user={"id": str(user["id"]), "email": user["email"], "role": role},
        user_id=str(user["id"]), email=user["email"], role=role
    )

async def _update_last_login(user_id):
    pool = get_pool()
    async with pool.acquire() as conn:
        await conn.execute("UPDATE users SET last_login_at = NOW() WHERE id = $1", user_id)

@router.get("/session", response_model=SessionResponse)
async def current_session(user=Depends(get_current_session)):
    return SessionResponse(
        success=True, message="Active session.", authenticated=True,
        user={"id": user["user_id"], "email": user["email"], "role": user["role"]},
        user_id=user["user_id"], email=user["email"], role=user["role"]
    )

@router.post("/logout")
async def logout(response: Response, request: Request,
                 credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)):
    token = request.cookies.get(COOKIE_NAME)
    if not token and credentials:
        token = credentials.credentials
    if token:
        await repository.revoke_session(hash_session_token(token))
    clear_session_cookie(response)
    return {"success": True, "message": "Logout successful."}
