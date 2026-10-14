from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db_session
from app.api.middleware import client_ip as trusted_client_ip
from app.api.schemas.public_reports import PublicReportRequest, PublicReportResponse
from app.application.public_reports import PublicReportService, report_reference

router = APIRouter(prefix="/v1/public", tags=["Safety"])

_RELATIONSHIP = {
    "rights_holder": "I am the rights holder",
    "agent": "Authorized agent / representative",
    "employee": "Employee of the rights holder",
}
_ROLE = {
    "self": "Yes, it's me",
    "other": "No",
    "on_behalf": "Reporting on behalf of someone",
}


def _report_text(payload: PublicReportRequest) -> tuple[str, str, str, str]:
    """(name, target text, summary, body) stored on the complaint case."""
    if payload.kind == "copyright":
        body = "\n\n".join(
            [
                f"Relationship: {_RELATIONSHIP[payload.relationship or 'rights_holder']}",
                f"Copyrighted work:\n{(payload.work_description or '').strip()}",
                f"Material on SaveStream:\n{(payload.locations or '').strip()}",
                "Good-faith statement: confirmed",
                "Accuracy and authority statement: confirmed",
                f"Electronic signature: {(payload.signature or '').strip()}",
            ]
        )
        summary = "Copyright notice: " + (payload.work_description or "").strip().splitlines()[0]
        return (payload.name or "").strip(), payload.locations or "", summary, body
    body = "\n\n".join(
        [
            f"Being recorded: {(payload.target or '').strip()}",
            f"Is the reporter the person in the stream: {_ROLE[payload.reporter_role or 'other']}",
            f"What's happening:\n{(payload.description or '').strip()}",
        ]
    )
    summary = "Unauthorized recording: " + (payload.target or "").strip()
    return payload.email, payload.target or "", summary, body


@router.post(
    "/reports",
    response_model=PublicReportResponse,
    status_code=201,
    operation_id="createPublicReport",
)
async def create_public_report(
    payload: PublicReportRequest,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> PublicReportResponse:
    settings = request.app.state.settings
    name, target_text, summary, body = _report_text(payload)
    case = await PublicReportService(
        session, settings, request.app.state.rate_limiter
    ).submit(
        kind=payload.kind,
        name=name,
        email=payload.email,
        target_text=target_text,
        summary=summary,
        body=body,
        client_ip=trusted_client_ip(request, settings.trusted_proxy_cidrs),
        turnstile_token=payload.turnstile_token,
    )
    await session.commit()
    return PublicReportResponse(reference=report_reference(case.id), kind=payload.kind)
