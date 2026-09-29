import time
from multiprocessing import Process
from pathlib import Path

from adapters.media_processor import FFmpegMediaProcessor
from adapters.tiktok_gateway import TikTokLiveGateway
from core.tiktok_api import TikTokAPI
from engine import EngineEvent, RecordingEngine, RecordingRequest
from engine.exceptions import LiveStreamUnavailableError
from utils.logger_manager import logger
from utils.video_management import VideoManagement
from utils.custom_exceptions import LiveNotFound, UserLiveError, \
    TikTokRecorderError
from utils.enums import Mode, Error, TimeOut, TikTokError


class TikTokRecorder:

    # Recordings smaller than this are treated as empty/garbage and removed
    # (a real live stream produces far more than this within seconds).
    MIN_VALID_RECORDING_BYTES = 100 * 1024  # 100 KB

    def __init__(
        self,
        url,
        user,
        room_id,
        mode,
        automatic_interval,
        cookies,
        proxy,
        output,
        duration,
        use_telegram,
    ):
        # Setup TikTok API client
        self.tiktok = TikTokAPI(proxy=proxy, cookies=cookies)

        # TikTok Data
        self.url = url
        self.user = user
        self.room_id = room_id

        # Tool Settings
        self.mode = mode
        self.automatic_interval = automatic_interval
        self.duration = duration
        self.output = output

        # Upload Settings
        self.use_telegram = use_telegram

        # Check if the user's country is blacklisted
        self.check_country_blacklisted()

        # Retrieve sec_uid if the mode is FOLLOWERS
        if self.mode == Mode.FOLLOWERS:
            self.sec_uid = self.tiktok.get_sec_uid()
            if self.sec_uid is None:
                raise TikTokRecorderError("Failed to retrieve sec_uid.")

            logger.info(f"Followers mode activated\n")
        else:
            # Get live information based on the provided user data
            if self.url:
                self.user, self.room_id = \
                    self.tiktok.get_room_and_user_from_url(self.url)

            if not self.user:
                self.user = self.tiktok.get_user_from_room_id(self.room_id)

            if not self.room_id:
                self.room_id = self.tiktok.get_room_id_from_user(self.user)

            logger.info(
                f"USERNAME: {self.user}" + ("\n" if not self.room_id else ""))
            logger.info(f"ROOM_ID:  {self.room_id}" + (
                "\n" if not self.tiktok.is_room_alive(self.room_id) else ""))

        # If proxy is provided, set up the HTTP client without the proxy
        if proxy:
            self.tiktok = TikTokAPI(proxy=None, cookies=cookies)

    def run(self):
        """
        runs the program in the selected mode. 
        
        If the mode is MANUAL, it checks if the user is currently live and
        if so, starts recording.
        
        If the mode is AUTOMATIC, it continuously checks if the user is live
        and if not, waits for the specified timeout before rechecking.
        If the user is live, it starts recording.
        """

        if self.mode == Mode.MANUAL:
            self.manual_mode()

        elif self.mode == Mode.AUTOMATIC:
            self.automatic_mode()

        elif self.mode == Mode.FOLLOWERS:
            self.followers_mode()

    def manual_mode(self):
        if not self.tiktok.is_room_alive(self.room_id):
            raise UserLiveError(
                f"@{self.user}: {TikTokError.USER_NOT_CURRENTLY_LIVE}"
            )

        self.start_recording(self.user, self.room_id)

    def automatic_mode(self):
        while True:
            try:
                self.room_id = self.tiktok.get_room_id_from_user(self.user)
                self.manual_mode()

            except UserLiveError as ex:
                logger.info(ex)
                logger.info(f"Waiting {self.automatic_interval} minutes before recheck\n")
                time.sleep(self.automatic_interval * TimeOut.ONE_MINUTE)

            except LiveNotFound as ex:
                logger.error(f"Live not found: {ex}")
                logger.info(f"Waiting {self.automatic_interval} minutes before recheck\n")
                time.sleep(self.automatic_interval * TimeOut.ONE_MINUTE)

            except ConnectionError:
                logger.error(Error.CONNECTION_CLOSED_AUTOMATIC)
                time.sleep(TimeOut.CONNECTION_CLOSED * TimeOut.ONE_MINUTE)

            except Exception as ex:
                logger.error(f"Unexpected error: {ex}\n")

    def followers_mode(self):
        active_recordings = {}  # follower -> Process

        while True:
            try:
                followers = self.tiktok.get_followers_list(self.sec_uid)

                for follower in followers:
                    if follower in active_recordings:
                        if not active_recordings[follower].is_alive():
                            logger.info(f'Recording of @{follower} finished.')
                            del active_recordings[follower]
                        else:
                            continue

                    try:
                        room_id = self.tiktok.get_room_id_from_user(follower)

                        if not room_id or not self.tiktok.is_room_alive(room_id):
                            #logger.info(f"@{follower} is not live. Skipping...")
                            continue

                        logger.info(f"@{follower} is live. Starting recording...")

                        process = Process(
                            target=self.start_recording,
                            args=(follower, room_id)
                        )
                        process.start()
                        active_recordings[follower] = process

                        time.sleep(2.5)

                    except Exception as e:
                        logger.error(f'Error while processing @{follower}: {e}')
                        continue

                print()
                delay = self.automatic_interval * TimeOut.ONE_MINUTE
                logger.info(f'Waiting {delay} minutes for the next check...')
                time.sleep(delay)

            except UserLiveError as ex:
                logger.info(ex)
                logger.info(f"Waiting {self.automatic_interval} minutes before recheck\n")
                time.sleep(self.automatic_interval * TimeOut.ONE_MINUTE)

            except ConnectionError:
                logger.error(Error.CONNECTION_CLOSED_AUTOMATIC)
                time.sleep(TimeOut.CONNECTION_CLOSED * TimeOut.ONE_MINUTE)

            except Exception as ex:
                logger.error(f"Unexpected error: {ex}\n")

    def start_recording(self, user, room_id):
        """Record one live session through the reusable recording engine."""
        if self.duration:
            logger.info(f"Started recording for {self.duration} seconds ")
        else:
            logger.info("Started recording...")

        logger.info("[PRESS CTRL + C ONCE TO STOP]")

        output_dir = (
            Path(self.output)
            if isinstance(self.output, str) and self.output != ""
            else Path(".")
        )

        engine = RecordingEngine(
            TikTokLiveGateway(self.tiktok),
            FFmpegMediaProcessor(
                converter=VideoManagement.convert_flv_to_mp4,
            ),
        )
        request = RecordingRequest(
            username=user,
            room_id=room_id,
            output_dir=output_dir,
            duration_seconds=self.duration,
            min_valid_bytes=self.MIN_VALID_RECORDING_BYTES,
        )

        def log_engine_event(event: EngineEvent) -> None:
            if event.kind in {"failed", "retrying"}:
                detail = (event.details or {}).get("error")
                logger.error(
                    "%s%s",
                    event.message,
                    f": {detail}" if detail else "",
                )
            elif event.kind in {
                "stream_ended",
                "stop_requested",
                "discarded",
            }:
                logger.info("%s", event.message)

        connection_retry_delay = 0.0
        if self.mode == Mode.AUTOMATIC:
            connection_retry_delay = (
                TimeOut.CONNECTION_CLOSED * TimeOut.ONE_MINUTE
            )

        try:
            result = engine.record(
                request,
                on_event=log_engine_event,
                transient_retry_delay_seconds=2.0,
                connection_retry_delay_seconds=connection_retry_delay,
            )
        except LiveStreamUnavailableError as exc:
            raise LiveNotFound(TikTokError.RETRIEVE_LIVE_URL) from exc

        logger.info(f"Recording finished: {result.source_path}\n")

        if result.discarded:
            return

        if self.use_telegram and result.artifact_path is not None:
            from upload.telegram import Telegram

            Telegram().upload(str(result.artifact_path))

    def check_country_blacklisted(self):
        is_blacklisted = self.tiktok.is_country_blacklisted()
        if not is_blacklisted:
            return False

        if self.room_id is None:
            raise TikTokRecorderError(TikTokError.COUNTRY_BLACKLISTED)

        if self.mode == Mode.AUTOMATIC:
            raise TikTokRecorderError(TikTokError.COUNTRY_BLACKLISTED_AUTO_MODE)

        elif self.mode == Mode.FOLLOWERS:
            raise TikTokRecorderError(TikTokError.COUNTRY_BLACKLISTED_FOLLOWERS_MODE)

        return is_blacklisted
