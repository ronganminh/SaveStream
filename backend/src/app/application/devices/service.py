from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.devices import UpsertDeviceRequest
from app.application.identity.service import utcnow
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import DeviceRegistration


class DeviceService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def upsert(
        self,
        principal: AuthPrincipal,
        device_id: str,
        payload: UpsertDeviceRequest,
    ) -> DeviceRegistration:
        normalized_id = device_id.strip()
        if not normalized_id:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Device id must not be blank",
                status_code=400,
            )
        row = await self.session.scalar(
            select(DeviceRegistration).where(
                DeviceRegistration.user_id == principal.user_id,
                DeviceRegistration.device_id == normalized_id,
            )
        )
        if row is None:
            row = DeviceRegistration(
                user_id=principal.user_id,
                session_id=principal.session_id,
                device_id=normalized_id,
                platform=payload.platform,
                push_token=payload.push_token,
                device_name=payload.device_name,
                app_version=payload.app_version,
                locale=payload.locale,
            )
            self.session.add(row)
        else:
            row.session_id = principal.session_id
            row.platform = payload.platform
            row.push_token = payload.push_token
            row.device_name = payload.device_name
            row.app_version = payload.app_version
            row.locale = payload.locale
            row.updated_at = utcnow()
        await self.session.commit()
        await self.session.refresh(row)
        return row

    async def delete(
        self,
        principal: AuthPrincipal,
        device_id: str,
    ) -> None:
        row = await self.session.scalar(
            select(DeviceRegistration).where(
                DeviceRegistration.user_id == principal.user_id,
                DeviceRegistration.device_id == device_id.strip(),
            )
        )
        if row is None:
            return
        await self.session.delete(row)
        await self.session.commit()
