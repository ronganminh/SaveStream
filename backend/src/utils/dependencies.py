from __future__ import annotations

import importlib.util
import shutil
from dataclasses import dataclass

from .logger_manager import logger


@dataclass(frozen=True, slots=True)
class MissingDependency:
    import_name: str
    install_name: str


class RuntimeDependencyError(RuntimeError):
    pass


_REQUIRED_PYTHON_PACKAGES = (
    MissingDependency("distro", "distro"),
    MissingDependency("ffmpeg", "ffmpeg-python"),
    MissingDependency("curl_cffi", "curl-cffi"),
    MissingDependency("requests", "requests"),
    MissingDependency("pyrogram", "Pyrogram"),
)


def find_missing_dependencies() -> list[str]:
    missing = [
        dependency.install_name
        for dependency in _REQUIRED_PYTHON_PACKAGES
        if importlib.util.find_spec(dependency.import_name) is None
    ]
    if shutil.which("ffmpeg") is None:
        missing.append("ffmpeg (system binary)")
    return missing


def ensure_runtime_dependencies() -> None:
    """Validate runtime dependencies without mutating the host environment."""
    missing = find_missing_dependencies()
    if not missing:
        return
    joined = ", ".join(missing)
    logger.error("Missing runtime dependencies: %s", joined)
    raise RuntimeDependencyError(
        "Missing runtime dependencies: "
        f"{joined}. Install the locked project dependencies before running the CLI."
    )
