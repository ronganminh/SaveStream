from __future__ import annotations

from fastapi import APIRouter, Depends, Path, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.devices import UpsertDeviceRequest
from app.application.devices.service import DeviceService
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1/me/devices", tags=["Devices"])


@router.put(
    "/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="upsertDevice",
)
async def upsert_device(
    payload: UpsertDeviceRequest,
    device_id: str = Path(min_length=1, max_length=160),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    await DeviceService(session).upsert(principal, device_id, payload)


@router.delete(
    "/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="deleteDevice",
)
async def delete_device(
    device_id: str = Path(min_length=1, max_length=160),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    await DeviceService(session).delete(principal, device_id)
