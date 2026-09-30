from __future__ import annotations

import argparse
import asyncio
import statistics
import time

import httpx


async def run_one(
    client: httpx.AsyncClient,
    url: str,
    semaphore: asyncio.Semaphore,
    token: str | None,
) -> tuple[bool, float]:
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    async with semaphore:
        start = time.perf_counter()
        try:
            response = await client.get(url, headers=headers)
            ok = 200 <= response.status_code < 500
        except httpx.HTTPError:
            ok = False
        return ok, time.perf_counter() - start


async def run(args: argparse.Namespace) -> int:
    semaphore = asyncio.Semaphore(args.concurrency)
    url = args.base_url.rstrip("/") + args.path
    async with httpx.AsyncClient(timeout=args.timeout) as client:
        results = await asyncio.gather(
            *[
                run_one(client, url, semaphore, args.token)
                for _ in range(args.requests)
            ]
        )
    latencies = [duration for _, duration in results]
    failures = sum(1 for ok, _ in results if not ok)
    ordered = sorted(latencies)
    p95 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.95))]
    print(
        "requests=%d failures=%d mean_ms=%.2f p95_ms=%.2f max_ms=%.2f"
        % (
            len(results),
            failures,
            statistics.mean(latencies) * 1000,
            p95 * 1000,
            max(latencies) * 1000,
        )
    )
    return 1 if failures / max(len(results), 1) > args.max_failure_ratio else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--path", default="/health/live")
    parser.add_argument("--requests", type=int, default=100)
    parser.add_argument("--concurrency", type=int, default=10)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--token")
    parser.add_argument("--max-failure-ratio", type=float, default=0.01)
    args = parser.parse_args()
    if args.requests <= 0 or args.concurrency <= 0:
        parser.error("requests and concurrency must be positive")
    return asyncio.run(run(args))


if __name__ == "__main__":
    raise SystemExit(main())
