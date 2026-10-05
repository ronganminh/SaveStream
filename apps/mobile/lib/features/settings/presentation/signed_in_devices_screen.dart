/// S09 — Signed-in devices.
import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class SignedInDevicesScreen extends StatefulWidget {
  const SignedInDevicesScreen({super.key});

  @override
  State<SignedInDevicesScreen> createState() => _SignedInDevicesScreenState();
}

class _SignedInDevicesScreenState extends State<SignedInDevicesScreen> {
  final List<_DeviceItem> _devices = <_DeviceItem>[
    const _DeviceItem(kind: _DeviceKind.iphone, current: true),
    const _DeviceItem(kind: _DeviceKind.web),
    const _DeviceItem(kind: _DeviceKind.android),
  ];

  void _remove(int index) {
    setState(() => _devices.removeAt(index));
    SsSnackbar.show(context, context.l10n.deviceSignedOutToast);
  }

  void _removeOthers() {
    setState(() => _devices.removeWhere((_DeviceItem item) => !item.current));
    SsSnackbar.show(context, context.l10n.otherDevicesSignedOutToast);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.signedInDevicesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          for (int index = 0; index < _devices.length; index += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: SsCard(
                child: SsListTile(
                  title: switch (_devices[index].kind) {
                    _DeviceKind.iphone => context.l10n.signedDeviceIphoneTitle,
                    _DeviceKind.web => context.l10n.signedDeviceWebTitle,
                    _DeviceKind.android =>
                      context.l10n.signedDeviceAndroidTitle,
                  },
                  subtitle: switch (_devices[index].kind) {
                    _DeviceKind.iphone => context.l10n.currentDeviceLabel,
                    _DeviceKind.web => context.l10n.signedDeviceWebDetail,
                    _DeviceKind.android =>
                      context.l10n.signedDeviceAndroidDetail,
                  },
                  leading: Icon(
                    _devices[index].current
                        ? Icons.smartphone_rounded
                        : Icons.devices_other_rounded,
                  ),
                  trailing: _devices[index].current
                      ? Text(context.l10n.currentDeviceLabel)
                      : TextButton(
                          onPressed: () => _remove(index),
                          child: Text(context.l10n.logoutAction),
                        ),
                ),
              ),
            ),
          if (_devices.length > 1)
            SsSecondaryButton(
              label: context.l10n.logoutOtherDevicesAction,
              onPressed: _removeOthers,
            ),
        ],
      ),
    );
  }
}

enum _DeviceKind { iphone, web, android }

class _DeviceItem {
  const _DeviceItem({required this.kind, this.current = false});

  final _DeviceKind kind;
  final bool current;
}
