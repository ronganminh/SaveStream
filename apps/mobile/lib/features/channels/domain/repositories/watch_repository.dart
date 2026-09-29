import '../models/watch_summary.dart';

abstract interface class WatchRepository {
  Future<List<WatchSummary>> listWatches();

  Future<WatchSummary?> getWatch(String id);
}
