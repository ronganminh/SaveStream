import '../models/channel_verification.dart';
import '../models/watch_summary.dart';

abstract interface class WatchRepository {
  Future<List<WatchSummary>> listWatches();

  Future<WatchSummary?> getWatch(String id);

  Future<WatchSummary> createWatch(CreateWatchCommand command);

  Future<WatchSummary?> setAutoRecord(String id, {required bool enabled});

  Future<WatchSummary?> setNotifyOnLive(String id, {required bool enabled});

  Future<WatchSummary?> pauseWatch(String id);

  Future<WatchSummary?> resumeWatch(String id);

  Future<void> deleteWatch(String id);
}

/// Lookup is deliberately a separate capability so older repository fakes and
/// offline test doubles do not have to implement a network-only operation.
abstract interface class CreatorLookupRepository {
  Future<CreatorLookupResult> lookupCreator(CreateWatchCommand command);
}

/// Ownership verification with a code in the channel's TikTok bio
/// (`/v1/watches/{id}/verification`). Separate for the same reason as
/// [CreatorLookupRepository].
abstract interface class ChannelVerificationRepository {
  /// Current state, without creating a code.
  Future<ChannelVerification> getVerification(String watchId);

  /// The channel's current code, or a new one when none is valid.
  Future<ChannelVerification> startVerification(String watchId);

  /// Asks the server to look for the code in the bio.
  Future<ChannelVerification> checkVerification(String watchId);
}
