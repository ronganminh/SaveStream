from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d4_runtime_settings_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]

    assert paths["/admin/settings"]["get"]["operationId"] == "listAdminRuntimeSettings"

    update = paths["/admin/settings/{setting_key}"]["put"]
    assert update["operationId"] == "updateAdminRuntimeSetting"
    assert any(
        parameter["name"] == "X-Admin-Step-Up"
        for parameter in update["parameters"]
    )

    reset = paths["/admin/settings/{setting_key}/reset"]["post"]
    assert reset["operationId"] == "resetAdminRuntimeSetting"
    assert any(
        parameter["name"] == "X-Admin-Step-Up"
        for parameter in reset["parameters"]
    )

    schemas = document["components"]["schemas"]
    assert "AdminRuntimeSetting" in schemas
    assert "AdminRuntimeSettingUpdateRequest" in schemas
    assert "AdminRuntimeSettingResetRequest" in schemas
