from __future__ import annotations

import argparse
import asyncio

from app.application.billing.service import (
    BillingAdminService,
    BillingReconciliationService,
)
from app.infrastructure.db.session import Database
from app.infrastructure.payments.factory import selected_payment_provider
from app.settings import get_app_settings


async def _run(args: argparse.Namespace) -> None:
    settings = get_app_settings()
    database = Database(settings.database_url)
    provider = selected_payment_provider(settings)
    try:
        async with database.session() as session:
            admin = BillingAdminService(session, provider)
            if args.command == "package-create":
                package = await admin.create_package(
                    code=args.code,
                    name=args.name,
                    credits=args.credits,
                    amount_minor=args.amount_minor,
                    currency=args.currency,
                )
                print(str(package.id))
                return
            if args.command == "package-disable":
                await admin.disable_package(args.package_id)
                print(args.package_id)
                return
            if args.command == "refund":
                refund = await admin.request_refund(
                    payment_order_id=args.payment_order_id,
                    amount_minor=args.amount_minor,
                    credits=args.credits,
                    idempotency_key=args.idempotency_key,
                )
                print(str(refund.id))
                return
            if args.command == "reconcile":
                count = await BillingReconciliationService(
                    session,
                    provider,
                ).run_once()
                print(count)
                return
            raise RuntimeError(f"unknown command: {args.command}")
    finally:
        await database.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="savestream-billing-admin")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("package-create")
    create.add_argument("--code", required=True)
    create.add_argument("--name", required=True)
    create.add_argument("--credits", required=True, type=int)
    create.add_argument("--amount-minor", required=True, type=int)
    create.add_argument("--currency", required=True)

    disable = sub.add_parser("package-disable")
    disable.add_argument("--package-id", required=True)

    refund = sub.add_parser("refund")
    refund.add_argument("--payment-order-id", required=True)
    refund.add_argument("--amount-minor", required=True, type=int)
    refund.add_argument("--credits", required=True, type=int)
    refund.add_argument("--idempotency-key", required=True)

    sub.add_parser("reconcile")
    return parser


def main() -> None:
    asyncio.run(_run(build_parser().parse_args()))


if __name__ == "__main__":
    main()
