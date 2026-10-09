"""Bound a CI integration-test subprocess and its child processes.

Flutter iOS test discovery can hang after an otherwise successful Xcode build;
without a group watchdog the job can wait until GitHub's 75-minute cap.
"""
from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--seconds', type=int, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == '--':
        command = command[1:]
    if not command or args.seconds <= 0:
        parser.error('provide a positive deadline and a subprocess after --')

    child = subprocess.Popen(command, start_new_session=True)

    def terminate_group(sig: int) -> None:
        try:
            os.killpg(child.pid, sig)
        except ProcessLookupError:
            pass

    def on_signal(sig: int, _frame: object) -> None:
        terminate_group(signal.SIGTERM)
        try:
            child.wait(timeout=8)
        except subprocess.TimeoutExpired:
            terminate_group(signal.SIGKILL)
            child.wait()
        raise SystemExit(128 + sig)

    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGTERM, on_signal)
    try:
        return child.wait(timeout=args.seconds)
    except subprocess.TimeoutExpired:
        print(f'::error::CI device test exceeded {args.seconds}s: {command}', flush=True)
        terminate_group(signal.SIGTERM)
        try:
            child.wait(timeout=8)
        except subprocess.TimeoutExpired:
            terminate_group(signal.SIGKILL)
            child.wait()
        return 124


if __name__ == '__main__':
    sys.exit(main())
