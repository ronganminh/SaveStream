import pytest

from app.settings import AppSettings


def test_app_settings_parse_cors_and_dependencies(monkeypatch) -> None:
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "test")
    monkeypatch.setenv(
        "SAVESTREAM_CORS_ALLOW_ORIGINS",
        "https://a.example, https://b.example",
    )
    monkeypatch.setenv("SAVESTREAM_DEPENDENCY_TIMEOUT_SECONDS", "3.5")
    settings = AppSettings.from_env()
    assert settings.environment == "test"
    assert settings.cors_allow_origins == ("https://a.example", "https://b.example")
    assert settings.dependency_timeout_seconds == 3.5


def test_wildcard_cors_is_rejected(monkeypatch) -> None:
    monkeypatch.setenv("SAVESTREAM_CORS_ALLOW_ORIGINS", "*")
    with pytest.raises(ValueError):
        AppSettings.from_env()
