from app.main import create_app
from tests.identity_helpers import identity_settings


def test_phase8_private_routes_do_not_change_public_openapi() -> None:
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()
    assert all(not path.startswith("/v1/admin") for path in generated["paths"])
    assert "/metrics" not in generated["paths"]
