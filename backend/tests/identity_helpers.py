from __future__ import annotations

import asyncio
from datetime import timezone

from sqlalchemy import select

from app.infrastructure.db.models import Base, OneTimeToken, User
from app.infrastructure.db.session import Database
from app.infrastructure.security.tokens import TokenService
from app.settings import AppSettings


def identity_settings(database_url: str, *, login_rate_limit: int = 20) -> AppSettings:
    return AppSettings(
        environment="test",
        database_url=database_url,
        redis_url="redis://localhost:6379/15",
        celery_broker_url="memory://",
        celery_result_backend="cache+memory://",
        minio_endpoint="http://localhost:9000",
        minio_access_key="test",
        minio_secret_key="test",
        jwt_secret="phase3-test-secret-that-is-not-production",
        cors_allow_origins=("https://testserver",),
        login_rate_limit=login_rate_limit,
        auth_write_rate_limit=50,
    )


def create_schema(database_url: str) -> None:
    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
        finally:
            await database.close()

    asyncio.run(run())


def one_time_token(settings: AppSettings, email: str, purpose: str) -> str:
    async def run() -> str:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                statement = (
                    select(OneTimeToken, User)
                    .join(User, User.id == OneTimeToken.user_id)
                    .where(
                        User.normalized_email == email.casefold(),
                        OneTimeToken.purpose == purpose,
                        OneTimeToken.consumed_at.is_(None),
                    )
                    .order_by(OneTimeToken.created_at.desc())
                )
                result = (await session.execute(statement)).first()
                assert result is not None
                token_row, user = result
                created_at = token_row.created_at
                expires_at = token_row.expires_at
                if created_at.tzinfo is None:
                    created_at = created_at.replace(tzinfo=timezone.utc)
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
                return TokenService(settings).issue_one_time_token(
                    token_id=token_row.id,
                    user_id=user.id,
                    purpose=token_row.purpose,
                    issued_at=created_at,
                    expires_at=expires_at,
                )
        finally:
            await database.close()

    return asyncio.run(run())
