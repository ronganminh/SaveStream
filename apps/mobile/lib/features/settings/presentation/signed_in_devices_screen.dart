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
    const _DeviceItem(name: 'iPhone 15', detail: 'This device', current: true),
    const _DeviceItem(name: 'Chrome on macOS', detail: 'Web · 2 hours ago'),
    const _DeviceItem(name: 'Pixel 8', detail: 'Android · 5 days ago'),
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
                  title: _devices[index].name,
                  subtitle: _devices[index].detail,
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

class _DeviceItem {
  const _DeviceItem({
    required this.name,
    required this.detail,
    this.current = false,
  });

  final String name;
  final String detail;
  final bool current;
}
