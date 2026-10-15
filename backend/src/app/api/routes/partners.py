from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, Header, Query, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.middleware import client_ip as trusted_client_ip
from app.api.routes.admin import _context, _require_scope, _require_step_up
from app.api.schemas.partners import (
    AdminPartnerActionRequest,
    AdminPartnerApplicationListResponse,
    AdminPartnerApplicationResponse,
    AdminPartnerRewardRequest,
    PartnerApplicationReceipt,
    PartnerApplicationRequest,
    PartnerStoryListResponse,
    PartnerStoryResponse,
)
from app.application.audit.service import AuditService
from app.application.partners import MAX_PHOTO_BYTES, STATUSES, PartnerService
from app.application.public_reports import report_reference
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.application.watches.resume import resume_credit_paused_watches
from app.infrastructure.db.admin_models import PartnerApplication
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.models import User

public_router = APIRouter(prefix="/v1/public", tags=["Partners"])
admin_router = APIRouter(prefix="/v1/admin/partners", tags=["Admin"], include_in_schema=False)


def _reference(application: PartnerApplication) -> str:
    return "PA-" + report_reference(application.id).removeprefix("SR-")


def _response(
    application: PartnerApplication,
    *,
    account: User | None = None,
    reward: CreditLedgerEntry | None = None,
) -> AdminPartnerApplicationResponse:
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
        account_user_id=str(account.id) if account else None,
        reward_credits=reward.amount if reward else None,
        reward_granted_at=reward.created_at if reward else None,
    )


async def _responses(
    service: PartnerService, rows: list[PartnerApplication]
) -> list[AdminPartnerApplicationResponse]:
    accounts = await service.accounts_by_email([row.email for row in rows])
    rewards = await service.rewards(rows)
    return [
        _response(row, account=accounts.get(row.email), reward=rewards.get(row.id))
        for row in rows
    ]


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


async def _photo_response(
    request: Request, application: PartnerApplication, *, cache_control: str
) -> Response:
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
        headers={"Cache-Control": cache_control},
    )


@public_router.get(
    "/partner-stories",
    response_model=PartnerStoryListResponse,
    operation_id="listPartnerStories",
)
async def list_partner_stories(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> PartnerStoryListResponse:
    rows = await PartnerService(session, request.app.state.settings).published_stories()
    return PartnerStoryListResponse(
        items=[
            PartnerStoryResponse(
                id=str(row.id),
                name=row.name,
                tiktok_handle=row.tiktok_handle,
                niche=row.niche,
                story=row.story,
                has_photo=row.photo_key is not None,
                published_at=row.published_at,
            )
            for row in rows
        ]
    )


@public_router.get(
    "/partner-stories/{application_id}/photo",
    response_class=Response,
    operation_id="getPartnerStoryPhoto",
    responses={200: {"content": {"image/png": {}, "image/jpeg": {}}}},
)
async def get_partner_story_photo(
    application_id: str,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    application = await PartnerService(session, request.app.state.settings).published_story(
        application_id
    )
    # Short cache so an unpublished story's photo disappears quickly.
    return await _photo_response(request, application, cache_control="public, max-age=300")


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
    service = PartnerService(session, request.app.state.settings)
    rows, counts = await service.list(status=status_filter, query=query)
    return AdminPartnerApplicationListResponse(
        items=await _responses(service, rows), counts=counts
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
    return (await _responses(service, [await service.get(application_id)]))[0]


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
    return await _photo_response(request, application, cache_control="private, no-store")


@admin_router.post("/{application_id}/actions", response_model=AdminPartnerApplicationResponse)
async def act_on_partner_application(
    application_id: str,
    payload: AdminPartnerActionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPartnerApplicationResponse:
    _require_scope(principal, "admin:partners:write")
    service = PartnerService(session, request.app.state.settings)
    application, before = await service.transition(
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
    return (await _responses(service, [application]))[0]


@admin_router.post("/{application_id}/reward", response_model=AdminPartnerApplicationResponse)
async def grant_partner_reward(
    application_id: str,
    payload: AdminPartnerRewardRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPartnerApplicationResponse:
    """Grant the Partner Program reward (default 50 h) once per application:
    a credit ledger adjustment plus an audit entry, behind step-up like any
    manual credit grant."""
    _require_scope(principal, "admin:partners:write")
    _require_scope(principal, "admin:credits:adjust")
    await _require_step_up(
        principal=principal, session=session, request=request, token=step_up_token
    )
    service = PartnerService(session, request.app.state.settings)
    application, user, entry = await service.grant_reward(
        application_id=application_id, hours=payload.hours, reason=payload.reason
    )
    await resume_credit_paused_watches(session, user.id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="partner.reward_granted",
        resource_type="partner_application",
        resource_id=str(application.id),
        context=_context(request),
        reason=payload.reason,
        after_state={
            "user_id": str(user.id),
            "hours": payload.hours,
            "credits": entry.amount,
            "transaction_id": str(entry.id),
        },
    )
    await session.commit()
    return _response(application, account=user, reward=entry)
