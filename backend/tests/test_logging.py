import json, logging
from utils.logger_manager import JsonFormatter, redact_secrets

def test_secret_redaction():
    msg='Authorization: Bearer access-secret sessionid="cookie-secret" bot_token=telegram-secret https://alice:proxy-secret@proxy.example:8080'
    redacted=redact_secrets(msg)
    for secret in ['access-secret','cookie-secret','telegram-secret','proxy-secret']:
        assert secret not in redacted

def test_json_formatter_redacts():
    r=logging.LogRecord('savestream.test',logging.INFO,__file__,1,'refresh_token=%s',('refresh-secret',),None)
    payload=json.loads(JsonFormatter().format(r)); assert payload['message']=='refresh_token=[REDACTED]'
