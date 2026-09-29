from typing import Protocol


class HealthCheck(Protocol):
    async def ping(self) -> bool: ...
