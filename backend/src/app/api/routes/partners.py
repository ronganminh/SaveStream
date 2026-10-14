from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.middleware import client_ip as trusted_client_ip
from app.api.routes.admin import _context, _require_scope
from app.api.schemas.partners import (
    AdminPartnerActionRequest,
    AdminPartnerApplicationListResponse,
    AdminPartnerApplicationResponse,
    PartnerApplicationReceipt,
    PartnerApplicationRequest,
)
from app.application.audit.service import AuditService
from app.application.partners import MAX_PHOTO_BYTES, STATUSES, PartnerService
from app.application.public_reports import report_reference
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.admin_models import PartnerApplication

public_router = APIRouter(prefix="/v1/public", tags=["Partners"])
admin_router = APIRouter(prefix="/v1/admin/partners", tags=["Admin"], include_in_schema=False)


def _reference(application: PartnerApplication) -> str:
    return "PA-" + report_reference(application.id).removeprefix("SR-")


def _response(application: PartnerApplication) -> AdminPartnerApplicationResponse:
    return AdminPartnerApplicationResponse(
        id=str(application.id),
        reference=_reference(application),
        name=application.name,
        email=application.email,
        tiktok_handle=application.tiktok_handle,
        other_channel_url=application.other_channel_url,
        niche=application.niche,
        story=application.story,
        has_photo=application.photo_key is not None,
        status=application.status,  # type: ignore[arg-type]
        consent_texts=list(application.consent_texts or []),
        terms_version=application.terms_version,
        privacy_version=application.privacy_version,
        consent_ip=application.consent_ip,
        consent_user_agent=application.consent_user_agent,
        consent_withdrawn_at=application.consent_withdrawn_at,
        published_at=application.published_at,
        created_at=application.created_at,
        updated_at=application.updated_at,
    )


@public_router.post(
    "/partner-applications",
    response_model=PartnerApplicationReceipt,
    status_code=201,
    operation_id="createPartnerApplication",
)
async def create_partner_application(
    payload: PartnerApplicationRequest,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> PartnerApplicationReceipt:
    settings = request.app.state.settings
    service = PartnerService(
        session, settings, request.app.state.rate_limiter, request.app.state.minio
    )
    client_ip = trusted_client_ip(request, settings.trusted_proxy_cidrs)
    if (payload.website or "").strip():
        await service.count_honeypot(client_ip=client_ip)
        return PartnerApplicationReceipt(reference="PA-00000000")
    application = await service.apply(
        name=payload.name,
        email=payload.email,
        tiktok_handle=payload.tiktok_handle,
        other_channel_url=payload.other_channel_url,
        niche=payload.niche,
        story=payload.story,
        photo_data_url=payload.photo,
        consent_owns_account=payload.consent_owns_account,
        consent_display=payload.consent_display,
        client_ip=client_ip,
        user_agent=request.headers.get("user-agent"),
        turnstile_token=payload.turnstile_token,
    )
    await session.commit()
    return PartnerApplicationReceipt(reference=_reference(application))


@admin_router.get("", response_model=AdminPartnerApplicationListResponse)
async def list_partner_applications(
    request: Request,
    status_filter: str | None = Query(default=None, alias="status"),
    query: str | None = Query(default=None, max_length=200),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPartnerApplicationListResponse:
    _require_scope(principal, "admin:partners:read")
    if status_filter and status_filter not in STATUSES:
        raise ApplicationError("VALIDATION_ERROR", "Invalid status", status_code=400)
    rows, counts = await PartnerService(session, request.app.state.settings).list(
        status=status_filter, query=query
    )
    return AdminPartnerApplicationListResponse(
        items=[_response(row) for row in rows], counts=counts
    )


@admin_router.get("/{application_id}", response_model=AdminPartnerApplicationResponse)
async def get_partner_application(
    application_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPartnerApplicationResponse:
    _require_scope(principal, "admin:partners:read")
    service = PartnerService(session, request.app.state.settings)
    return _response(await service.get(application_id))


@admin_router.get(
    "/{application_id}/photo",
    response_class=Response,
    responses={200: {"content": {"image/png": {}, "image/jpeg": {}}}},
)
async def get_partner_application_photo(
    application_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_scope(principal, "admin:partners:read")
    application = await PartnerService(session, request.app.state.settings).get(application_id)
    if application.photo_key is None:
        raise ApplicationError("RESOURCE_NOT_FOUND", "No photo", status_code=404)
    found = await asyncio.to_thread(
        request.app.state.minio.get_bytes, application.photo_key, max_bytes=MAX_PHOTO_BYTES
    )
    if found is None:
        raise ApplicationError("RESOURCE_NOT_FOUND", "No photo", status_code=404)
    data, _ = found
    return Response(
        content=data,
        media_type=application.photo_content_type or "image/jpeg",
        headers={"Cache-Control": "private, no-store"},
    )


@admin_router.post("/{application_id}/actions", response_model=AdminPartnerApplicationResponse)
async def act_on_partner_application(
    application_id: str,
    payload: AdminPartnerActionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPartnerApplicationResponse:
    _require_scope(principal, "admin:partners:write")
    application, before = await PartnerService(session, request.app.state.settings).transition(
        application_id=application_id, action=payload.action, reviewer_id=principal.user_id
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action=f"partner.{payload.action}",
        resource_type="partner_application",
        resource_id=str(application.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"status": before},
        after_state={"status": application.status},
    )
    await session.commit()
    return _response(application)
