// State tối giản bằng ValueNotifier/ChangeNotifier để demo chạy được.
// Production: thay bằng Riverpod/Bloc, giữ nguyên tên & enum (xem docs/ARCHITECTURE.md).
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'models.dart';

final session = ValueNotifier<SessionState>(SessionState.valid);
final appGate = ValueNotifier<AppGate>(AppGate.ok);
final isOnline = ValueNotifier<bool>(true); // G01 · nguồn: OS connectivity
final currentPlan = ValueNotifier<Plan>(Plan.free); // gate bằng entitlement backend, KHÔNG từ store client

/// Local recorder — không phụ thuộc session (G05).
class RecorderController extends ChangeNotifier {
  ActiveRecording? _active;
  Timer? _tick;

  ActiveRecording? get active => _active;
  bool get isActive => _active != null;

  String start(Creator c, {Engine engine = Engine.local}) {
    final id = 's${DateTime.now().millisecondsSinceEpoch}';
    _active = ActiveRecording(
        sessionId: id, creator: c, engine: engine, status: RecordingStatus.starting, elapsed: Duration.zero);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_active?.sessionId != id) return;
      _active = _active!.copyWith(status: RecordingStatus.recording);
      notifyListeners();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        final a = _active;
        if (a == null) return;
        _active = a.copyWith(elapsed: a.elapsed + const Duration(seconds: 1), bytes: a.bytes + 310000);
        notifyListeners();
      });
    });
    return id;
  }

  Future<void> stop({RecordingEndReason reason = RecordingEndReason.userStopped}) async {
    _tick?.cancel();
    if (_active == null) return;
    _active = _active!.copyWith(status: RecordingStatus.finalizing);
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900));
    _active = null;
    notifyListeners();
  }
}

final recorder = RecorderController();
