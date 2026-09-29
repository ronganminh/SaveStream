from http_utils import http_client
class FakeSession:
    def __init__(self): self.headers={}; self.cookies={}; self.proxies={}; self.calls=[]
    def get(self,url,**kwargs): self.calls.append((url,kwargs)); return object()
def test_http_client_applies_default_and_stream_timeouts(monkeypatch):
    session=FakeSession(); monkeypatch.setattr(http_client,'is_termux',lambda: True); monkeypatch.setattr(http_client.requests,'Session',lambda: session)
    client=http_client.HttpClient(); client.get('https://example.test/normal'); client.get('https://example.test/stream',stream=True)
    assert session.calls[0][1]['timeout']==client.settings.http_timeout_seconds
    assert session.calls[1][1]['timeout']==client.settings.http_stream_timeout_seconds
