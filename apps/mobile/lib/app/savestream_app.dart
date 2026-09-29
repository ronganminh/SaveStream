import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../features/design_system/presentation/component_gallery_screen.dart';
import '../l10n/l10n.dart';
import 'app_settings_controller.dart';
import 'theme/ss_theme.dart';

class SaveStreamApp extends StatefulWidget {
  const SaveStreamApp({required this.config, this.settings, super.key});

  final AppConfig config;
  final AppSettingsController? settings;

  @override
  State<SaveStreamApp> createState() => _SaveStreamAppState();
}

class _SaveStreamAppState extends State<SaveStreamApp> {
  late final AppSettingsController _settings;
  late final bool _ownsSettings;

  @override
  void initState() {
    super.initState();
    _ownsSettings = widget.settings == null;
    _settings = widget.settings ?? AppSettingsController();
  }

  @override
  void dispose() {
    if (_ownsSettings) {
      _settings.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
          theme: SsTheme.light(),
          darkTheme: SsTheme.dark(),
          themeMode: _settings.themeMode,
          locale: _settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ComponentGalleryScreen(
            config: widget.config,
            settings: _settings,
          ),
        );
      },
    );
  }
}
