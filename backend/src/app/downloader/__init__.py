"""Public TikTok video downloader (web only).

Runs as its own service (`downloader` container, `app.downloader.app:app`) so
its traffic, CPU and failures stay apart from the API and LIVE recording.
Files are streamed straight from TikTok to the visitor; nothing is stored.
"""
