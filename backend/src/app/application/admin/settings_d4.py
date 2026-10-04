from __future__ import annotations

import re
import time
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import AdminRuntimeSetting
from app.settings import AppSettings

SettingKind = Literal["bool", "int", "version", "enum", "datetime"]
SettingValue = bool | int | str | None
DefaultFactory = Callable[[AppSettings], SettingValue]

_CACHE_TTL_SECONDS = 15.0
_CACHE: dict[str, tuple[float, dict[str, SettingValue]]] = {}
_VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")


@dataclass(frozen=True, slots=True)
class RuntimeSettingDefinition:
    key: str
    kind: SettingKind
    description: str
    default: DefaultFactory
    minimum: int | None = None
    maximum: int | None = None
    choices: tuple[str, ...] = ()
    nullable: bool = False


def _setting_definitions() -> tuple[RuntimeSettingDefinition, ...]:
    return (
        RuntimeSettingDefinition(
            "maintenance_active",
            "bool",
            "Put user-facing API flows into maintenance mode.",
            lambda settings: settings.maintenance_active,
        ),
        RuntimeSettingDefinition(
            "maintenance_eta",
            "datetime",
            "Expected maintenance completion time in UTC.",
            lambda settings: (
                settings.maintenance_eta.astimezone(timezone.utc).isoformat()
                if settings.maintenance_eta
                else None
            ),
            nullable=True,
        ),
        RuntimeSettingDefinition(
            "app_min_supported_android",
            "version",
            "Minimum supported Android app version.",
            lambda settings: settings.app_min_supported_android,
        ),
        RuntimeSettingDefinition(
            "app_min_supported_ios",
            "version",
            "Minimum supported iOS app version.",
            lambda settings: settings.app_min_supported_ios,
        ),
        RuntimeSettingDefinition(
            "signup_credits",
            "int",
            "Trial cloud minutes granted after email verification.",
            lambda settings: settings.signup_credits,
            minimum=0,
            maximum=100_000,
        ),
        RuntimeSettingDefinition(
            "pro_local_recording",
            "enum",
            "Whether Pro local recording is unlimited or disabled.",
            lambda settings: settings.pro_local_recording,
            choices=("unlimited", "disabled"),
        ),
        RuntimeSettingDefinition(
            "free_local_daily_minutes",
            "int",
            "Free local recording minutes granted per day.",
            lambda settings: settings.free_local_daily_minutes,
            minimum=0,
            maximum=1_440,
        ),
        RuntimeSettingDefinition(
            "reward_daily_cap",
            "int",
            "Maximum rewarded-ad grants per user per day.",
            lambda settings: settings.reward_daily_cap,
            minimum=0,
            maximum=100,
        ),
        RuntimeSettingDefinition(
            "reward_minutes",
            "int",
            "Local recording minutes granted per valid reward.",
            lambda settings: settings.reward_minutes,
            minimum=0,
            maximum=1_440,
        ),
        RuntimeSettingDefinition(
            "free_max_watches",
            "int",
            "Maximum watched channels for Free accounts.",
            lambda _settings: 3,
            minimum=0,
            maximum=1_000,
        ),
        RuntimeSettingDefinition(
            "pro_max_watches",
            "int",
            "Maximum watched channels for Pro accounts.",
            lambda _settings: 20,
            minimum=0,
            maximum=10_000,
        ),
        RuntimeSettingDefinition(
            "pro_max_concurrent_cloud_recordings",
            "int",
            "Maximum concurrent cloud recordings per Pro account.",
            lambda _settings: 3,
            minimum=0,
            maximum=100,
        ),
        RuntimeSettingDefinition(
            "recording_retention_days",
            "int",
            "Cloud recording retention days for purchased accounts.",
            lambda settings: settings.recording_retention_days,
            minimum=0,
            maximum=3_650,
        ),
        RuntimeSettingDefinition(
            "recording_retention_days_free",
            "int",
            "Cloud recording retention days for trial-only accounts.",
            lambda settings: settings.recording_retention_days_free,
            minimum=0,
            maximum=3_650,
        ),
        RuntimeSettingDefinition(
            "payment_web_enabled",
            "bool",
            "Allow web checkout when the web payment provider is configured.",
            lambda settings: settings.payment_provider != "disabled",
        ),
        RuntimeSettingDefinition(
            "payment_app_store_enabled",
            "bool",
            "Allow App Store purchases when store purchases are configured.",
            lambda settings: settings.store_purchase_provider != "disabled",
        ),
        RuntimeSettingDefinition(
            "payment_google_play_enabled",
            "bool",
            "Allow Google Play purchases when store purchases are configured.",
            lambda settings: settings.store_purchase_provider != "disabled",
        ),
    )


SETTING_DEFINITIONS = _setting_definitions()
SETTINGS_BY_KEY = {item.key: item for item in SETTING_DEFINITIONS}


def _definition(key: str) -> RuntimeSettingDefinition:
    definition = SETTINGS_BY_KEY.get(key)
    if definition is None:
        raise ApplicationError(
            "RESOURCE_NOT_FOUND",
            "Runtime setting is not exposed to Admin",
            status_code=404,
        )
    return definition


def _normalize(definition: RuntimeSettingDefinition, value: object) -> SettingValue:
    if value is None:
        if definition.nullable:
            return None
        raise ApplicationError(
            "VALIDATION_ERROR",
            f"{definition.key} cannot be null",
            status_code=400,
        )

    if definition.kind == "bool":
        if type(value) is not bool:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be a boolean",
                status_code=400,
            )
        return value

    if definition.kind == "int":
        if type(value) is not int:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be an integer",
                status_code=400,
            )
        if definition.minimum is not None and value < definition.minimum:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be at least {definition.minimum}",
                status_code=400,
            )
        if definition.maximum is not None and value > definition.maximum:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be at most {definition.maximum}",
                status_code=400,
            )
        return value

    if not isinstance(value, str):
        raise ApplicationError(
            "VALIDATION_ERROR",
            f"{definition.key} must be a string",
            status_code=400,
        )
    normalized = value.strip()

    if definition.kind == "enum":
        if normalized not in definition.choices:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be one of: {', '.join(definition.choices)}",
                status_code=400,
            )
        return normalized

    if definition.kind == "version":
        if not _VERSION_RE.fullmatch(normalized):
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be a semantic version such as 1.2.3",
                status_code=400,
            )
        return normalized

    if definition.kind == "datetime":
        try:
            parsed = datetime.fromisoformat(normalized.replace("Z", "+00:00"))
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"{definition.key} must be an ISO 8601 datetime",
                status_code=400,
            ) from exc
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc).isoformat()

    return normalized


class RuntimeSettingsService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings
        self.cache_key = settings.database_url

    def invalidate(self) -> None:
        _CACHE.pop(self.cache_key, None)

    async def _overrides(self) -> dict[str, SettingValue]:
        cached = _CACHE.get(self.cache_key)
        now = time.monotonic()
        if cached is not None and now - cached[0] < _CACHE_TTL_SECONDS:
            return dict(cached[1])

        rows = list((await self.session.scalars(select(AdminRuntimeSetting))).all())
        values: dict[str, SettingValue] = {}
        for row in rows:
            definition = SETTINGS_BY_KEY.get(row.key)
            if definition is None:
                continue
            values[row.key] = _normalize(definition, row.value)
        _CACHE[self.cache_key] = (now, dict(values))
        return values

    async def value(self, key: str) -> SettingValue:
        definition = _definition(key)
        overrides = await self._overrides()
        return overrides.get(key, definition.default(self.settings))

    async def list_settings(self) -> list[dict[str, object]]:
        rows = {
            row.key: row
            for row in (await self.session.scalars(select(AdminRuntimeSetting))).all()
            if row.key in SETTINGS_BY_KEY
        }
        items: list[dict[str, object]] = []
        for definition in SETTING_DEFINITIONS:
            row = rows.get(definition.key)
            default = definition.default(self.settings)
            value = _normalize(definition, row.value) if row is not None else default
            items.append(
                {
                    "key": definition.key,
                    "kind": definition.kind,
                    "description": definition.description,
                    "value": value,
                    "default_value": default,
                    "source": "database" if row is not None else "environment",
                    "minimum": definition.minimum,
                    "maximum": definition.maximum,
                    "choices": list(definition.choices),
                    "nullable": definition.nullable,
                    "updated_by_user_id": (
                        str(row.updated_by_user_id)
                        if row is not None and row.updated_by_user_id is not None
                        else None
                    ),
                    "updated_at": row.updated_at if row is not None else None,
                }
            )
        return items

    async def update(
        self,
        key: str,
        value: object,
        *,
        actor_user_id: uuid.UUID,
    ) -> tuple[SettingValue, SettingValue]:
        definition = _definition(key)
        normalized = _normalize(definition, value)
        previous = await self.value(key)
        row = await self.session.get(AdminRuntimeSetting, key)
        if row is None:
            row = AdminRuntimeSetting(
                key=key,
                value=normalized,
                updated_by_user_id=actor_user_id,
            )
            self.session.add(row)
        else:
            row.value = normalized
            row.updated_by_user_id = actor_user_id
            row.updated_at = datetime.now(timezone.utc)
        await self.session.flush()
        self.invalidate()
        return previous, normalized

    async def reset(self, key: str) -> tuple[SettingValue, SettingValue]:
        definition = _definition(key)
        previous = await self.value(key)
        row = await self.session.get(AdminRuntimeSetting, key)
        if row is not None:
            await self.session.delete(row)
            await self.session.flush()
        self.invalidate()
        return previous, definition.default(self.settings)
