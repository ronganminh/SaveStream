from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class PublicReportRequest(BaseModel):
    """Body of the public /report form (copyright notice or abuse report)."""

    model_config = ConfigDict(extra="forbid")

    kind: Literal["copyright", "abuse"]
    email: str = Field(min_length=3, max_length=320, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    # Copyright notice (Copyright Policy §2).
    name: str | None = Field(default=None, max_length=200)
    relationship: Literal["rights_holder", "agent", "employee"] | None = None
    work_description: str | None = Field(default=None, max_length=5_000)
    locations: str | None = Field(default=None, max_length=5_000)
    good_faith: bool = False
    accurate_and_authorized: bool = False
    signature: str | None = Field(default=None, max_length=200)
    # Abuse / unauthorized recording.
    target: str | None = Field(default=None, max_length=2_048)
    reporter_role: Literal["self", "other", "on_behalf"] | None = None
    description: str | None = Field(default=None, max_length=10_000)
    turnstile_token: str | None = Field(default=None, max_length=4_096)
    # Honeypot: a hidden "website" input people never see; bots fill it in.
    website: str | None = Field(default=None, max_length=2_048)

    @model_validator(mode="after")
    def validate_kind_fields(self):
        if self.kind == "copyright":
            missing = [
                label
                for label, value in (
                    ("name", self.name),
                    ("relationship", self.relationship),
                    ("work_description", self.work_description),
                    ("locations", self.locations),
                    ("signature", self.signature),
                )
                if not (value or "").strip()
            ]
            if missing:
                raise ValueError(f"Missing required fields: {', '.join(missing)}")
            if not (self.good_faith and self.accurate_and_authorized):
                raise ValueError("Both statements must be confirmed")
        else:
            if not (self.target or "").strip() or not (self.description or "").strip():
                raise ValueError("target and description are required")
            if self.reporter_role is None:
                raise ValueError("reporter_role is required")
        return self


class PublicReportResponse(BaseModel):
    reference: str
    kind: Literal["copyright", "abuse"]
