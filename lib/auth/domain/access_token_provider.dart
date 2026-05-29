abstract interface class AccessTokenProvider {
  Future<String?> ensureValidAccessToken();

  Future<String?> refreshAccessToken();
}
