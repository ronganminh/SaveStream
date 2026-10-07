import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/api/api_providers.dart';
import '../core/config/app_config.dart';
import '../core/config/app_config_provider.dart';
import '../core/mock/mock_providers.dart';
import '../core/mock/mock_scenario.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/auth/data/repositories/mock_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/channels/domain/repositories/watch_repository.dart';
import '../features/channels/presentation/controllers/watch_providers.dart';
import '../features/recordings/domain/repositories/recording_repository.dart';
import '../features/recordings/presentation/controllers/recording_providers.dart';
import '../features/settings/domain/repositories/notifications_repository.dart';
import '../features/settings/domain/repositories/profile_repository.dart';
import '../features/settings/presentation/controllers/notification_feed_providers.dart';
import '../features/settings/presentation/controllers/notification_preferences_providers.dart';
import '../features/settings/presentation/controllers/settings_providers.dart';
import '../l10n/l10n.dart';
import '../platform/push_runtime.dart';
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
    this.profileRepository,
    this.notificationsRepository,
    this.notificationPreferencesRepository,
    this.foregroundPushMessages,
    this.openedPushMessages,
    this.mockScenario = MockScenario.success,
    this.authMockScenario = AuthMockScenario.success,
    this.extraOverrides = const <Override>[],
    super.key,
  });

  final AppConfig config;
  final AppSettingsController? settings;
  final AppSessionController? session;
  final AuthRepository? authRepository;
  final ApiClient? apiClient;
  final WatchRepository? watchRepository;
  final RecordingRepository? recordingRepository;
  final ProfileRepository? profileRepository;
  final NotificationsRepository? notificationsRepository;
  final NotificationPreferencesRepository? notificationPreferencesRepository;
  final Stream<ForegroundPushMessage>? foregroundPushMessages;
  final Stream<ForegroundPushMessage>? openedPushMessages;
  final MockScenario mockScenario;
  final AuthMockScenario authMockScenario;
  final List<Override> extraOverrides;

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
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<ForegroundPushMessage>? _foregroundPushSubscription;
  StreamSubscription<ForegroundPushMessage>? _openedPushSubscription;

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
    _foregroundPushSubscription = widget.foregroundPushMessages?.listen(
      _showForegroundPush,
    );
    _openedPushSubscription = widget.openedPushMessages?.listen(_openPush);
  }

  void _showForegroundPush(ForegroundPushMessage message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ScaffoldMessengerState? messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (message.body.isNotEmpty) Text(message.body),
              ],
            ),
          ),
        );
    });
  }

  void _openPush(ForegroundPushMessage message) {
    _router.go(
      PushRuntime.routeFor(
        kind: message.kind,
        resourceType: message.resourceType,
        resourceId: message.resourceId,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_foregroundPushSubscription?.cancel());
    unawaited(_openedPushSubscription?.cancel());
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
        appConfigProvider.overrideWithValue(widget.config),
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

        if (widget.profileRepository != null)
          profileRepositoryProvider.overrideWithValue(
            widget.profileRepository!,
          ),
        if (widget.notificationsRepository != null)
          notificationsRepositoryProvider.overrideWithValue(
            widget.notificationsRepository!,
          ),
        if (widget.notificationPreferencesRepository != null)
          notificationPreferencesRepositoryProvider.overrideWithValue(
            widget.notificationPreferencesRepository!,
          ),
        ...widget.extraOverrides,
      ],
      child: AnimatedBuilder(
        animation: _settings,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp.router(
            scaffoldMessengerKey: _messengerKey,
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
