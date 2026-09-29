class LiveStreamUnavailableError(RuntimeError):
    """The platform did not return a playable live stream URL."""


class TransientStreamError(RuntimeError):
    """Transport-level stream failure that may be retried."""


class StreamConnectionError(TransientStreamError):
    """Connection was closed and may require a longer backoff."""
