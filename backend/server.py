
"""
CyberNexus Access
Main Backend Application
Version: 0.0.1
"""

import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from backend.database import connect_database, close_database, database_health
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from backend.session import router as session_router
from backend.ai import router as ai_router
from backend.automation import router as automation_router


# Application Configuration

APP_NAME = "CyberNexus Access"
APP_VERSION = "0.0.1"
API_PREFIX = "/api/v1"

ENVIRONMENT = os.getenv("APP_ENV", "development").lower()

ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5173"
    ).split(",")
    if origin.strip()
]

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s"
)

logger = logging.getLogger("cybernexus.access")


# Application Lifecycle

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("%s starting...", APP_NAME)
    await connect_database()
    yield
    await close_database()
    logger.info("%s shutting down...", APP_NAME)


# FastAPI Application

app = FastAPI(
    title=APP_NAME,
    description="Account Management and Access Control System",
    version=APP_VERSION,
    docs_url="/docs" if ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if ENVIRONMENT != "production" else None,
    openapi_url="/openapi.json" if ENVIRONMENT != "production" else None,
    lifespan=lifespan
)


# Middleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
        "X-Request-ID"
    ]
)


# Exception Handlers

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(
    request: Request,
    exc: StarletteHTTPException
):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "message": exc.detail
            }
        },
        headers=exc.headers
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError
):
    return JSONResponse(
        status_code=422,
        content={
            "success": False,
            "error": {
                "message": "Invalid request data.",
                "details": exc.errors()
            }
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(
    request: Request,
    exc: Exception
):
    logger.exception("Unhandled application exception")

    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "error": {
                "message": "An internal server error occurred."
            }
        }
    )


# API Routes

app.include_router(
    session_router,
    prefix=f"{API_PREFIX}/auth",
    tags=["Authentication"]
)

app.include_router(
    ai_router,
    prefix=f"{API_PREFIX}/ai",
    tags=["Artificial Intelligence"]
)

app.include_router(
    automation_router,
    prefix=f"{API_PREFIX}/automation",
    tags=["Automation"]
)


# System Health

@app.get("/", tags=["System"])
async def root():
    return {
        "success": True,
        "application": APP_NAME,
        "version": APP_VERSION,
        "status": "running"
    }


@app.get("/health", tags=["System"])
async def health():
    await database_health()
    return {
        "success": True,
        "status": "healthy",
        "database": "connected",
        "application": APP_NAME,
        "version": APP_VERSION
    }


# Application Entry Point

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "backend.server:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8000")),
        reload=ENVIRONMENT == "development"
    )


# Serve the frontend from the same origin as the API.
FRONTEND_DIR = Path(__file__).resolve().parent.parent / "frontend"
if FRONTEND_DIR.exists():
    app.mount("/", StaticFiles(directory=str(FRONTEND_DIR), html=True), name="frontend")
