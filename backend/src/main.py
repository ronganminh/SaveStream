import multiprocessing
import os
import signal
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def record_user(user, url, room_id, mode, interval, proxy, output, duration, use_telegram, cookies):
    from core.tiktok_recorder import TikTokRecorder
    from utils.logger_manager import logger
    try:
        TikTokRecorder(url=url, user=user, room_id=room_id, mode=mode, automatic_interval=interval,
                       cookies=cookies, proxy=proxy, output=output, duration=duration,
                       use_telegram=use_telegram).run()
    except Exception as exc:
        logger.error("%s", exc)


def run_recordings(args, mode, cookies):
    if isinstance(args.user, list):
        processes = []
        for user in args.user:
            process = multiprocessing.Process(target=record_user, args=(user, args.url, args.room_id, mode,
                args.automatic_interval, args.proxy, args.output, args.duration, args.telegram, cookies))
            process.start(); processes.append(process)
        for process in processes:
            process.join()
    else:
        record_user(args.user, args.url, args.room_id, mode, args.automatic_interval, args.proxy,
                    args.output, args.duration, args.telegram, cookies)


def main():
    from check_updates import check_updates
    from utils.args_handler import validate_and_parse_args
    from utils.custom_exceptions import TikTokRecorderError
    from utils.dependencies import RuntimeDependencyError, ensure_runtime_dependencies
    from utils.logger_manager import logger
    from utils.utils import read_cookies
    try:
        args, mode = validate_and_parse_args()
        ensure_runtime_dependencies()
        if args.update_check is True:
            logger.info("Checking for updates")
            if check_updates():
                return 0
        else:
            logger.info("Skipped update check")
        cookies = read_cookies()
        run_recordings(args, mode, cookies)
        return 0
    except RuntimeDependencyError as exc:
        logger.error("%s", exc); return 2
    except TikTokRecorderError as exc:
        logger.error("Application Error: %s", exc); return 1
    except Exception as exc:
        logger.critical("Generic Error: %s", exc, exc_info=True); return 1


def cli() -> int:
    from utils.utils import banner
    banner()
    signal.signal(signal.SIGINT, lambda _signal, _frame: sys.exit(0))
    multiprocessing.freeze_support()
    return main()


if __name__ == "__main__":
    raise SystemExit(cli())
