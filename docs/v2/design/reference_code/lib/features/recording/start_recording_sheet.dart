import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../widgets/widgets.dart';

/// R01-android / R01-ios — sheet xác nhận trước khi record Local.
Future<void> showStartRecordingSheet(BuildContext context, Creator c) {
  final ios = Platform.isIOS;
  return showSsBottomSheet(
    context,
    title: 'Record ${c.name}?',
    body: ios
        ? 'Giữ SaveStream mở trong lúc record. iOS có thể dừng record khi app chạy nền.'
        : 'Recording chạy nền với thông báo cố định. File lưu trên máy này.',
    content: const SsInlineAlert(
      tone: SsAlertTone.info,
      title: 'Dùng phút Free hôm nay',
      body: 'Hết phút, bạn có thể xem quảng cáo để thêm 10 phút.',
    ),
    actions: [
      SsButton(
        label: 'Bắt đầu record',
        icon: Icons.radio_button_checked_rounded,
        onPressed: () {
          Navigator.pop(context);
          final id = recorder.start(c);
          context.push('/recording/$id');
        },
      ),
      SsButton(label: 'Huỷ', variant: SsButtonVariant.tertiary, onPressed: () => Navigator.pop(context)),
    ],
  );
}
