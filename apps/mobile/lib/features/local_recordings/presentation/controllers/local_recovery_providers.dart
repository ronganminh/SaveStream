import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../platform/contracts/local_recovery_service.dart';
import '../../../../platform/platform_providers.dart';

final FutureProvider<LocalRecoveryCandidate?>
interruptedLocalRecordingProvider = FutureProvider<LocalRecoveryCandidate?>(
  (Ref ref) => ref.watch(localRecoveryServiceProvider).findInterrupted(),
);

final StreamProvider<LocalRecoveryProgress> localRecoveryProgressProvider =
    StreamProvider<LocalRecoveryProgress>(
      (Ref ref) => ref.watch(localRecoveryServiceProvider).watchProgress(),
    );
