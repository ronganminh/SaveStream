import logging
import pytest
from config import SettingsError, get_settings

def test_settings_are_typed(monkeypatch):
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "test")
    monkeypatch.setenv("SAVESTREAM_LOG_FORMAT", "console")
    monkeypatch.setenv("SAVESTREAM_LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("SAVESTREAM_HTTP_TIMEOUT_SECONDS", "7.5")
    get_settings.cache_clear(); settings=get_settings()
    assert settings.environment=="test" and settings.log_level==logging.DEBUG
    assert settings.http_timeout_seconds==7.5
    get_settings.cache_clear()

def test_invalid_timeout_fails_fast(monkeypatch):
    monkeypatch.setenv("SAVESTREAM_HTTP_TIMEOUT_SECONDS", "0"); get_settings.cache_clear()
    with pytest.raises(SettingsError): get_settings()
    get_settings.cache_clear()
