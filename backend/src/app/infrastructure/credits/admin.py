from __future__ import annotations

import argparse
import asyncio
import json
import uuid

from app.application.credits.service import (
    CreditAdminService,
    CreditReconciliationService,
)
from app.application.pricing.service import PricingAdminService
from app.infrastructure.db.session import Database
from app.settings import get_app_settings


async def _run(args: argparse.Namespace) -> None:
    database = Database(get_app_settings().database_url)
    try:
        async with database.session() as session:
            if args.command == "pricing-create":
                rule = await PricingAdminService(session).create_rule(
                    version=args.version,
                    policy_type=args.policy_type,
                    policy=json.loads(args.policy_json),
                    public_rules=json.loads(args.public_rules_json),
                    activate=args.activate,
                )
                print(str(rule.id))
                return
            if args.command == "pricing-activate":
                rule = await PricingAdminService(session).activate(args.version)
                print(rule.version)
                return
            if args.command == "adjust":
                entry = await CreditAdminService(session).adjust(
                    user_id=uuid.UUID(args.user_id),
                    amount=args.amount,
                    idempotency_key=args.idempotency_key,
                    reason=args.reason,
                )
                print(str(entry.id))
                return
            if args.command == "reconcile":
                result = await CreditReconciliationService(session).reconcile_account(
                    uuid.UUID(args.user_id)
                )
                print(
                    json.dumps(
                        {
                            "user_id": str(result.user_id),
                            "account_balance": result.account_balance,
                            "ledger_balance": result.ledger_balance,
                            "reserved": result.reserved,
                            "available": result.available,
                            "consistent": result.consistent,
                        },
                        sort_keys=True,
                    )
                )
                return
            raise RuntimeError(f"unknown command: {args.command}")
    finally:
        await database.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="savestream-credit-admin")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("pricing-create")
    create.add_argument("--version", required=True)
    create.add_argument("--policy-type", required=True)
    create.add_argument("--policy-json", required=True)
    create.add_argument("--public-rules-json", required=True)
    create.add_argument("--activate", action="store_true")

    activate = sub.add_parser("pricing-activate")
    activate.add_argument("--version", required=True)

    adjust = sub.add_parser("adjust")
    adjust.add_argument("--user-id", required=True)
    adjust.add_argument("--amount", required=True, type=int)
    adjust.add_argument("--idempotency-key", required=True)
    adjust.add_argument("--reason", required=True)

    reconcile = sub.add_parser("reconcile")
    reconcile.add_argument("--user-id", required=True)
    return parser


def main() -> None:
    asyncio.run(_run(build_parser().parse_args()))


if __name__ == "__main__":
    main()
