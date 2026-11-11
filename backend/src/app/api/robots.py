"""Keep the API hosts out of search engines.

api.savestream.online only serves JSON, media streams and the downloader; none
of it should be indexed. Every response (including error responses and the
downloader's file streams) carries ``X-Robots-Tag: noindex, nofollow``, and
``/robots.txt`` disallows everything. Cloudflare's managed robots.txt, if
enabled, adds its own comments on top of this file.
"""

from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import PlainTextResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

X_ROBOTS_TAG = "noindex, nofollow"
ROBOTS_TXT = "User-agent: *\nDisallow: /\n"

router = APIRouter(include_in_schema=False)


@router.get("/robots.txt", response_class=PlainTextResponse)
async def robots_txt() -> PlainTextResponse:
    return PlainTextResponse(ROBOTS_TXT, headers={"Cache-Control": "public, max-age=3600"})


class NoIndexMiddleware:
    """Adds X-Robots-Tag to every HTTP response (pure ASGI, so streaming
    responses are untouched)."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_header(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = [
                    (k, v) for k, v in message.get("headers", []) if k.lower() != b"x-robots-tag"
                ]
                headers.append((b"x-robots-tag", X_ROBOTS_TAG.encode()))
                message = {**message, "headers": headers}
            await send(message)

        await self.app(scope, receive, send_with_header)
