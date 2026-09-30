from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class ReservationStatus(str, Enum):
    ACTIVE = "active"
    SETTLED = "settled"
    RELEASED = "released"


@dataclass(frozen=True, slots=True)
class CreditBalance:
    posted: int
    reserved: int
    available: int
