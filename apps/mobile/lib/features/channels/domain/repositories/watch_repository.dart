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
