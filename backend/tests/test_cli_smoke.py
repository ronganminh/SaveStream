import subprocess, sys
from pathlib import Path
def test_cli_help_still_works():
    backend=Path(__file__).resolve().parents[1]
    result=subprocess.run([sys.executable,'src/main.py','-h'],cwd=backend,text=True,capture_output=True,timeout=10,check=False)
    assert result.returncode==0 and 'usage:' in result.stdout.lower() and 'TikTok Live Recorder' in result.stdout
