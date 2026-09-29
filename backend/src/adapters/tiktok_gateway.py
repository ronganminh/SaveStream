from __future__ import annotations

from http.client import HTTPException
from typing import Iterable

from requests import RequestException

from core.tiktok_api import TikTokAPI
from engine.exceptions import StreamConnectionError, TransientStreamError


class TikTokLiveGateway:
    """Adapter from the legacy TikTokAPI to the reusable engine port."""

    def __init__(self, api: TikTokAPI) -> None:
        self.api = api

    def get_live_url(self, room_id: str) -> str | None:
        try:
            return self.api.get_live_url(room_id)
        except ConnectionError as exc:
            raise StreamConnectionError(str(exc)) from exc
        except (RequestException, HTTPException) as exc:
            raise TransientStreamError(str(exc)) from exc

    def is_room_alive(self, room_id: str) -> bool:
        try:
            return self.api.is_room_alive(room_id)
        except ConnectionError as exc:
            raise StreamConnectionError(str(exc)) from exc
        except (RequestException, HTTPException) as exc:
            raise TransientStreamError(str(exc)) from exc

    def download_live_stream(self, live_url: str) -> Iterable[bytes]:
        try:
            yield from self.api.download_live_stream(live_url)
        except ConnectionError as exc:
            raise StreamConnectionError(str(exc)) from exc
        except (RequestException, HTTPException) as exc:
            raise TransientStreamError(str(exc)) from exc
