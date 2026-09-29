abstract final class AuthValidation {
  static bool isEmail(String value) {
    final String trimmed = value.trim();
    final int atIndex = trimmed.indexOf('@');
    return atIndex > 0 &&
        atIndex < trimmed.length - 3 &&
        trimmed.substring(atIndex + 1).contains('.');
  }
}
