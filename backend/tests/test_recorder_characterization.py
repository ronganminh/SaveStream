from pathlib import Path
from core.tiktok_recorder import TikTokRecorder
from utils.enums import Mode
class FakeTikTok:
    def __init__(self): self.alive_checks=0
    def get_live_url(self,_room_id): return 'https://cdn.example/live.flv'
    def is_room_alive(self,_room_id): self.alive_checks+=1; return self.alive_checks==1
    def download_live_stream(self,_live_url): yield b'tiny'
def test_tiny_recording_is_removed_before_conversion(tmp_path, monkeypatch):
    recorder=TikTokRecorder.__new__(TikTokRecorder); recorder.tiktok=FakeTikTok(); recorder.output=str(tmp_path); recorder.duration=None; recorder.mode=Mode.MANUAL; recorder.use_telegram=False
    called=False
    def mark(_path):
        nonlocal called; called=True
    monkeypatch.setattr('core.tiktok_recorder.VideoManagement.convert_flv_to_mp4',mark)
    recorder.start_recording('creator','room'); assert called is False; assert list(Path(tmp_path).glob('*.mp4'))==[]
