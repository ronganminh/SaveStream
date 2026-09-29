import sys, pytest
from utils.args_handler import validate_and_parse_args
from utils.custom_exceptions import ArgsParseError
from utils.enums import Mode

def test_manual_username_is_normalized(monkeypatch):
    monkeypatch.setattr(sys,'argv',['main.py','-user','@creator','-mode','manual'])
    args,mode=validate_and_parse_args(); assert args.user=='creator' and mode==Mode.MANUAL

def test_multiple_usernames_remain_a_list(monkeypatch):
    monkeypatch.setattr(sys,'argv',['main.py','-user','@alpha, beta','-mode','automatic'])
    args,mode=validate_and_parse_args(); assert args.user==['alpha','beta'] and mode==Mode.AUTOMATIC

def test_cli_rejects_conflicting_sources(monkeypatch):
    monkeypatch.setattr(sys,'argv',['main.py','-user','creator','-room_id','123','-mode','manual'])
    with pytest.raises(ArgsParseError): validate_and_parse_args()
