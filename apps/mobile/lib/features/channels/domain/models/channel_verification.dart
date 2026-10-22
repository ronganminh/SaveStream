/// Result of `POST /v1/watches/{id}/verification/check`.
enum VerificationCheckResult {
  verified('verified'),
  codeNotFound('code_not_found'),
  retryLater('retry_later');

  const VerificationCheckResult(this.apiValue);

  final String apiValue;
}

/// Ownership verification state of one channel (`ChannelVerificationResponse`).
///
/// Every date here comes from the server; the app never computes a deadline.
class ChannelVerification {
  const ChannelVerification({
    required this.watchId,
    required this.verified,
    this.ownerVerifiedAt,
    this.verificationDueAt,
    this.verificationRequired = false,
    this.code,
    this.expiresAt,
    this.checksLeft = 0,
    this.result,
    this.retryAfterSeconds,
  });

  final String watchId;
  final bool verified;
  final DateTime? ownerVerifiedAt;

  /// Recording needs verification from this time (grace period for old
  /// channels; "now" for channels added after verification existed).
  final DateTime? verificationDueAt;
  final bool verificationRequired;

  /// The bio code (`SS-XXXX`) while one is pending, else null.
  final String? code;

  /// When [code] stops being accepted.
  final DateTime? expiresAt;
  final int checksLeft;
  final VerificationCheckResult? result;
  final int? retryAfterSeconds;

  /// True when the code is past the server's `expires_at` at [now].
  bool isExpiredAt(DateTime now) {
    final DateTime? expires = expiresAt;
    return expires != null && !expires.isAfter(now);
  }
}
