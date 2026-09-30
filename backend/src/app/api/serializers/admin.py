from app.api.schemas.admin import AdminUserResponse, AuditLogResponse
from app.infrastructure.db.models import AuditLog, User


def admin_user_response(user: User) -> AdminUserResponse:
    return AdminUserResponse.model_validate(
        {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "role": user.role,
            "is_active": user.is_active,
            "email_verified_at": user.email_verified_at,
            "deletion_requested_at": user.deletion_requested_at,
            "created_at": user.created_at,
            "updated_at": user.updated_at,
        }
    )


def audit_log_response(row: AuditLog) -> AuditLogResponse:
    return AuditLogResponse(
        id=str(row.id),
        actor_user_id=str(row.actor_user_id) if row.actor_user_id else None,
        action=row.action,
        resource_type=row.resource_type,
        resource_id=row.resource_id,
        request_id=row.request_id,
        ip_address=row.ip_address,
        user_agent=row.user_agent,
        details=dict(row.details),
        created_at=row.created_at,
    )
