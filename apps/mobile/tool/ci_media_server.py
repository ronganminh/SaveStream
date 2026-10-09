"""Local-only deterministic media server for Android/iOS on-device CI.

Never serves a real creator's stream. Playback tests decode the committed,
project-owned web sample; Android local recording captures a real FLV byte
stream generated from the sample by ffmpeg inside CI.
"""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re
import time

SAMPLE = Path(__file__).resolve().parents[3] / 'apps/web/public/samples/video-01.mp4'


class MediaHandler(BaseHTTPRequestHandler):
    stream: Path

    def do_GET(self) -> None:
        if self.path == '/health':
            body = b'OK'
            self.send_response(200)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path == '/playback.mp4':
            media = SAMPLE
            mimetype = 'video/mp4'
        elif self.path == '/stream.flv':
            media = self.stream
            mimetype = 'video/x-flv'
        else:
            self.send_error(404)
            return
        if not media.is_file() or media.stat().st_size < 64_000:
            self.send_error(503, 'CI fixture unavailable')
            return
        size = media.stat().st_size
        start, end = 0, size - 1
        status = 200
        requested = self.headers.get('Range')
        if requested:
            match = re.fullmatch(r'bytes=(\d+)-(\d*)', requested)
            if match is None:
                self.send_error(416)
                return
            start = int(match.group(1))
            end = min(int(match.group(2)), size - 1) if match.group(2) else size - 1
            if start > end or start >= size:
                self.send_error(416)
                return
            status = 206
        self.send_response(status)
        self.send_header('Content-Type', mimetype)
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Length', str(end - start + 1))
        if status == 206:
            self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
        self.end_headers()
        try:
            with media.open('rb') as file:
                file.seek(start)
                left = end - start + 1
                while left:
                    chunk = file.read(min(8192, left))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    left -= len(chunk)
                    if self.path == '/stream.flv':
                        time.sleep(0.025)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Client stopped recording or seeking.

    def log_message(self, format: str, *args: object) -> None:
        if self.path != '/health':
            super().log_message(format, *args)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=18095)
    parser.add_argument('--flv', type=Path)
    args = parser.parse_args()
    MediaHandler.stream = args.flv or Path('/dev/null')
    server = ThreadingHTTPServer(('0.0.0.0', args.port), MediaHandler)
    print(f'CI media server ready, port={args.port}', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
