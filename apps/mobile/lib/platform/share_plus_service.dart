import 'package:share_plus/share_plus.dart';

import 'contracts/share_service.dart';

final class SharePlusService implements ShareService {
  const SharePlusService();

  @override
  Future<void> shareFile({
    required String filePath,
    String? displayName,
  }) async {
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(filePath)], title: displayName),
    );
  }
}
