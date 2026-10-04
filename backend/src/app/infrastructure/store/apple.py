from __future__ import annotations

import asyncio
import base64
import json
from datetime import datetime, timezone
from typing import Any, Mapping

from appstoreserverlibrary.api_client import (
    APIException,
    AsyncAppStoreServerAPIClient,
)
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
)

from app.domain.common.errors import ApplicationError
from app.settings import AppSettings

from .base import StoreReceiptVerifier, VerifiedStorePurchase, VerifiedStoreRefund


def _apple_environment(value: str) -> Environment:
    return (
        Environment.PRODUCTION
        if value == "production"
        else Environment.SANDBOX
    )


def _invalid(message: str, *, retryable: bool = False) -> ApplicationError:
    return ApplicationError(
        "STORE_RECEIPT_INVALID",
        message,
        status_code=422 if not retryable else 503,
        retryable=retryable,
    )


class AppleStoreReceiptVerifier(StoreReceiptVerifier):
    platform = "app_store"

    def __init__(
        self,
        settings: AppSettings,
        *,
        signed_data_verifier: Any | None = None,
        api_client: Any | None = None,
    ) -> None:
        self.settings = settings
        environment = _apple_environment(settings.app_store_environment)
        if signed_data_verifier is None:
            try:
                encoded_roots = json.loads(
                    settings.app_store_root_certificates_json
                )
                if not isinstance(encoded_roots, list) or not encoded_roots:
                    raise ValueError("no root certificates")
                roots = [
                    base64.b64decode(str(value), validate=True)
                    for value in encoded_roots
                ]
            except (ValueError, TypeError, json.JSONDecodeError) as exc:
                raise ValueError(
                    "SAVESTREAM_APP_STORE_ROOT_CERTIFICATES_JSON must be "
                    "a JSON array of base64 DER Apple root certificates"
                ) from exc
            signed_data_verifier = SignedDataVerifier(
                roots,
                True,
                environment,
                settings.app_store_bundle_id,
                (
                    settings.app_store_app_apple_id
                    if environment == Environment.PRODUCTION
                    else None
                ),
            )
        self.signed_data_verifier = signed_data_verifier
        self.api_client = api_client
        self.environment = environment

    async def verify_purchase(
        self,
        *,
        product_id: str,
        transaction_id: str,
        receipt: str,
    ) -> VerifiedStorePurchase:
        try:
            device_transaction = await asyncio.to_thread(
                self.signed_data_verifier.verify_and_decode_signed_transaction,
                receipt,
            )
        except VerificationException as exc:
            raise _invalid("App Store transaction JWS is invalid") from exc

        if (
            device_transaction.transactionId != transaction_id
            or device_transaction.productId != product_id
            or device_transaction.revocationDate is not None
        ):
            raise _invalid(
                "App Store transaction does not match the requested purchase"
            )

        client = self.api_client
        owns_client = client is None
        if client is None:
            client = AsyncAppStoreServerAPIClient(
                self.settings.app_store_private_key.encode("utf-8"),
                self.settings.app_store_key_id,
                self.settings.app_store_issuer_id,
                self.settings.app_store_bundle_id,
                self.environment,
            )
        try:
            response = await client.get_transaction_info(transaction_id)
            signed_server_transaction = response.signedTransactionInfo
            if not signed_server_transaction:
                raise _invalid(
                    "App Store transaction response is missing signed data"
                )
            server_transaction = await asyncio.to_thread(
                self.signed_data_verifier.verify_and_decode_signed_transaction,
                signed_server_transaction,
            )
        except APIException as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "App Store verification is temporarily unavailable",
                status_code=503,
                retryable=True,
            ) from exc
        except VerificationException as exc:
            raise _invalid("App Store server transaction JWS is invalid") from exc
        finally:
            if owns_client:
                await client.async_close()

        if (
            server_transaction.transactionId != transaction_id
            or server_transaction.productId != product_id
            or server_transaction.revocationDate is not None
        ):
            raise _invalid(
                "App Store server transaction does not match the purchase"
            )

        purchased_at = (
            datetime.fromtimestamp(
                server_transaction.purchaseDate / 1000,
                tz=timezone.utc,
            )
            if server_transaction.purchaseDate is not None
            else None
        )
        return VerifiedStorePurchase(
            platform=self.platform,
            product_id=product_id,
            transaction_id=transaction_id,
            purchased_at=purchased_at,
        )

    async def finalize_purchase(
        self,
        purchase: VerifiedStorePurchase,
    ) -> None:
        del purchase
        # StoreKit 2 finishes the transaction on-device. Server-side B5 only
        # verifies the signed transaction; Google requires explicit finalize.

    async def verify_refund_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> VerifiedStoreRefund:
        del headers
        try:
            envelope = json.loads(raw_body.decode("utf-8"))
            signed_payload = str(envelope["signedPayload"])
            notification = await asyncio.to_thread(
                self.signed_data_verifier.verify_and_decode_notification,
                signed_payload,
            )
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            VerificationException,
        ) as exc:
            raise _invalid("App Store notification is invalid") from exc

        if notification.rawNotificationType != "REFUND":
            raise _invalid("App Store notification is not a refund")
        if (
            notification.data is None
            or not notification.data.signedTransactionInfo
            or not notification.notificationUUID
        ):
            raise _invalid("App Store refund notification is incomplete")
        try:
            transaction = await asyncio.to_thread(
                self.signed_data_verifier.verify_and_decode_signed_transaction,
                notification.data.signedTransactionInfo,
            )
        except VerificationException as exc:
            raise _invalid(
                "App Store refund transaction JWS is invalid"
            ) from exc
        if (
            not transaction.transactionId
            or transaction.revocationDate is None
        ):
            raise _invalid("App Store refund transaction is incomplete")
        return VerifiedStoreRefund(
            platform=self.platform,
            transaction_id=transaction.transactionId,
            event_id=notification.notificationUUID,
        )
