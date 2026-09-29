enum WatchStatus {
  active('active'),
  paused('paused'),
  pausedInsufficientCredit('paused_insufficient_credit'),
  pausedError('paused_error'),
  disabled('disabled');

  const WatchStatus(this.apiValue);

  final String apiValue;
}

class WatchSummary {
  const WatchSummary({
    required this.id,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.isLive,
  });

  final String id;
  final String creatorDisplayName;
  final String creatorUsername;
  final WatchStatus status;
  final bool isLive;
}
