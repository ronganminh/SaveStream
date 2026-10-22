/// Revision dates of the published Terms of Use, Privacy Policy and
/// Acceptable Use Policy. They must match the backend
/// (`app/application/identity/legal.py`) and the web client
/// (`apps/web/src/lib/legal.ts`); sign-up sends them as consent evidence.
abstract final class LegalVersions {
  static const String terms = '2026-10-14';
  static const String privacy = '2026-10-14';
  static const String acceptableUse = '2026-10-05';
}

/// "I am 18 or older and agree to the Terms of Use, Privacy Policy and
/// Acceptable Use Policy." Created only after the user ticks the checkbox.
class LegalConsent {
  const LegalConsent({
    this.termsVersion = LegalVersions.terms,
    this.privacyVersion = LegalVersions.privacy,
    this.aupVersion = LegalVersions.acceptableUse,
  });

  /// The versions shown in this build of the app.
  static const LegalConsent current = LegalConsent();

  final String termsVersion;
  final String privacyVersion;
  final String aupVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'age_confirmed': true,
    'terms_version': termsVersion,
    'privacy_version': privacyVersion,
    'aup_accepted': true,
    'aup_version': aupVersion,
  };
}
