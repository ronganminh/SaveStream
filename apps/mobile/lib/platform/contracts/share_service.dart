abstract interface class ShareService {
  Future<void> shareFile({
    required String filePath,
    String? displayName,
  });
}

class FakeShareService implements ShareService {
  final List<({String filePath, String? displayName})> sharedFiles =
      <({String filePath, String? displayName})>[];

  @override
  Future<void> shareFile({
    required String filePath,
    String? displayName,
  }) async {
    sharedFiles.add((filePath: filePath, displayName: displayName));
  }
}
