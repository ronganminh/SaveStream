abstract interface class AccessTokenProvider {
  Future<String?> getAccessToken();
}

final class EmptyAccessTokenProvider implements AccessTokenProvider {
  const EmptyAccessTokenProvider();

  @override
  Future<String?> getAccessToken() async => null;
}
