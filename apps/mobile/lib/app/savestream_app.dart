import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/api/api_providers.dart';
import '../core/config/app_config.dart';
import '../core/mock/mock_providers.dart';
import '../core/mock/mock_scenario.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/auth/data/repositories/mock_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/channels/domain/repositories/watch_repository.dart';
import '../features/billing/domain/repositories/billing_repository.dart';
import '../features/billing/presentation/controllers/billing_providers.dart';
import '../features/channels/presentation/controllers/watch_providers.dart';
import '../features/credits/domain/repositories/credits_repository.dart';
import '../features/credits/presentation/controllers/credits_providers.dart';
import '../features/recordings/domain/repositories/recording_repository.dart';
import '../features/recordings/presentation/controllers/recording_providers.dart';
import '../l10n/l10n.dart';
import 'app_settings_controller.dart';
import 'lifecycle/app_lifecycle_controller.dart';
import 'router/app_router.dart';
import 'session/app_session_controller.dart';
import 'theme/ss_theme.dart';

class SaveStreamApp extends StatefulWidget {
  const SaveStreamApp({
    required this.config,
    this.settings,
    this.session,
    this.authRepository,
    this.apiClient,
    this.watchRepository,
    this.recordingRepository,
    this.creditsRepository,
    this.billingRepository,
    this.mockScenario = MockScenario.success,
    this.authMockScenario = AuthMockScenario.success,
    super.key,
  });

  final AppConfig config;
  final AppSettingsController? settings;
  final AppSessionController? session;
  final AuthRepository? authRepository;
  final ApiClient? apiClient;
  final WatchRepository? watchRepository;
  final RecordingRepository? recordingRepository;
  final CreditsRepository? creditsRepository;
  final BillingRepository? billingRepository;
  final MockScenario mockScenario;
  final AuthMockScenario authMockScenario;

  @override
  State<SaveStreamApp> createState() => _SaveStreamAppState();
}

class _SaveStreamAppState extends State<SaveStreamApp> {
  late final AppSettingsController _settings;
  late final AppSessionController _session;
  late final AppLifecycleController _lifecycle;
  late final GoRouter _router;
  late final bool _ownsSettings;
  late final bool _ownsSession;

  @override
  void initState() {
    super.initState();
    _ownsSettings = widget.settings == null;
    _ownsSession = widget.session == null;
    _settings = widget.settings ?? AppSettingsController();
    _session = widget.session ?? AppSessionController();
    _lifecycle = AppLifecycleController()..start();
    _router = createAppRouter(
      config: widget.config,
      settings: _settings,
      session: _session,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _lifecycle.dispose();
    if (_ownsSettings) _settings.dispose();
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        mockScenarioProvider.overrideWithValue(widget.mockScenario),
        authMockScenarioProvider.overrideWithValue(widget.authMockScenario),
        if (widget.authRepository != null)
          authRepositoryProvider.overrideWithValue(widget.authRepository!),
        if (widget.apiClient != null)
          apiClientProvider.overrideWithValue(widget.apiClient!),
        if (widget.watchRepository != null)
          watchRepositoryProvider.overrideWithValue(widget.watchRepository!),
        if (widget.recordingRepository != null)
          recordingRepositoryProvider.overrideWithValue(
            widget.recordingRepository!,
          ),
        if (widget.creditsRepository != null)
          creditsRepositoryProvider.overrideWithValue(
            widget.creditsRepository!,
          ),
        if (widget.billingRepository != null)
          billingRepositoryProvider.overrideWithValue(
            widget.billingRepository!,
          ),
      ],
      child: AnimatedBuilder(
        animation: _settings,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            restorationScopeId: 'savestream_app',
            onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
            theme: SsTheme.light(),
            darkTheme: SsTheme.dark(),
            themeMode: _settings.themeMode,
            locale: _settings.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
