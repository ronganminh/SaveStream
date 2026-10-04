from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.support_reports import (
    SupportReportCreateRequest,
    SupportReportResponse,
)
from app.application.support_reports import SupportReportService
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1/support", tags=["Support"])


@router.post(
    "/reports",
    response_model=SupportReportResponse,
    status_code=201,
    operation_id="createSupportReport",
)
async def create_support_report(
    payload: SupportReportCreateRequest,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> SupportReportResponse:
    diagnostics = payload.diagnostics
    report = await SupportReportService(session).create(
        user_id=principal.user_id,
        description=payload.message,
        recording_id=payload.recording_id,
        diagnostic_log=diagnostics,
        app_version=(
            str(diagnostics["app_version"])
            if diagnostics.get("app_version") is not None
            else None
        ),
        platform=(
            str(diagnostics["os"])
            if diagnostics.get("os") is not None
            else None
        ),
    )
    await session.commit()
    return SupportReportResponse(report_id=str(report.id))
