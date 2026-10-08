import json
from pathlib import Path
from core.tiktok_api import TikTokAPI
FIXTURES=Path(__file__).parent/'fixtures'
class FakeResponse:
    def __init__(self,text='',payload=None,status_code=200): self.text=text; self._payload=payload; self.status_code=status_code
    def json(self): return self._payload
    def raise_for_status(self): return None
class FakeClient:
    def __init__(self,response): self.response=response; self.cookies={}
    def get(self,_url=None,**_kwargs): return self.response
def bare_api(client):
    api=TikTokAPI.__new__(TikTokAPI); api.BASE_URL='https://www.tiktok.com'; api.WEBCAST_URL='https://webcast.tiktok.com'; api.http_client=client; api._http_client_stream=client; return api

def test_room_id_is_parsed_from_sanitized_sigi_state():
    api=bare_api(FakeClient(FakeResponse(text=(FIXTURES/'tiktok_live_page.html').read_text())))
    assert api.get_room_id_from_user('creator')=='7312345678901234567'

def test_live_url_keeps_current_highest_quality_selection():
    payload=json.loads((FIXTURES/'tiktok_room_info.json').read_text()); api=bare_api(FakeClient(FakeResponse(payload=payload)))
    assert api.get_live_url('7312345678901234567')=='https://cdn.example/full-hd.flv'

def test_room_alive_false_payload_is_preserved():
    payload=json.loads((FIXTURES/'tiktok_room_offline.json').read_text()); api=bare_api(FakeClient(FakeResponse(payload=payload)))
    assert api.is_room_alive('7312345678901234567') is False


def test_profile_metadata_is_extracted_from_sigi_state():
    profile_html = '''<script id="SIGI_STATE" type="application/json">{
      "UserModule":{"users":{"creator-id":{"uniqueId":"creator","nickname":"Creator LIVE","avatarLarger":"https://p16.tiktokcdn.com/avatar.jpeg"}}}
    }</script>'''
    api=bare_api(FakeClient(FakeResponse(text=profile_html)))

    profile = api.get_user_profile('@creator')

    assert profile is not None
    assert profile.username == 'creator'
    assert profile.display_name == 'Creator LIVE'
    assert profile.avatar_url == 'https://p16.tiktokcdn.com/avatar.jpeg'
