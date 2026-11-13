"""PostgreSQL connection pool and persistence helpers."""
import os
import asyncpg

_pool = None

async def connect_database():
    global _pool
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        raise RuntimeError("DATABASE_URL is required.")
    # Supabase transaction pooler commonly requires SSL.
    _pool = await asyncpg.create_pool(
        dsn=dsn,
        min_size=1,
        max_size=int(os.getenv("DB_POOL_MAX_SIZE", "5")),
        command_timeout=30,
        ssl="require",
        server_settings={"search_path": "cybernexus_access,public"},
    )
    async with _pool.acquire() as connection:
        await connection.execute("SELECT 1")

async def close_database():
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None

def get_pool():
    if _pool is None:
        raise RuntimeError("Database pool is not initialized.")
    return _pool

async def database_health():
    pool = get_pool()
    async with pool.acquire() as connection:
        await connection.fetchval("SELECT 1")
    return True
