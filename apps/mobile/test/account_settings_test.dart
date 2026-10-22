// The Account tab and its screens with the mock repositories: rows open
// the right screens, theme switches (language is hidden: v2.1.0 ships
// English only), delete can be cancelled,
// help search filters locally, the report form posts and confirms.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/account/data/report_repository.dart';
import 'package:savestream_mobile/features/account/presentation/account_providers.dart';
import 'package:savestream_mobile/features/account/presentation/account_screen.dart';
import 'package:savestream_mobile/features/account/presentation/help_center_screen.dart';
import 'package:savestream_mobile/features/account/presentation/legal_screen.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/settings/presentation/notification_preferences_screen.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  Future<void> openAccount(
    WidgetTester tester, {
    AppSettingsController? settings,
    AppSessionController? session,
    MockScenario mockScenario = MockScenario.success,
    List<Override> overrides = const <Override>[],
  }) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: testConfig(),
        settings: settings,
        session: session,
        mockScenario: mockScenario,
        extraOverrides: overrides,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-account')));
    await tester.pumpAndSettle();
  }

  /// A tall view so the report form is built in full.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> push(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(AccountScreen))).push(location);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the fallback name for a profile without one', (
    WidgetTester tester,
  ) async {
    await openAccount(tester, mockScenario: MockScenario.empty);

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('SaveStream user'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
  });

  testWidgets('switches between System Light and Dark from Theme screen', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await openAccount(tester, settings: settings);
    await push(tester, AppRoutes.theme);

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('System'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.system);
  });

  testWidgets('English only: no Language row, Vietnamese not offered', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await openAccount(tester, settings: settings);
    expect(
      find.byKey(const ValueKey<String>('account-language')),
      findsNothing,
    );

    // The screen stays routable (for a later release) but offers English only.
    await push(tester, AppRoutes.language);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Vietnamese'), findsNothing);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(settings.locale.languageCode, 'en');

    settings.setLocale(const Locale('vi'));
    await tester.pumpAndSettle();
    expect(settings.locale.languageCode, 'en');
    expect(find.text('Ngôn ngữ'), findsNothing);
  });

  testWidgets('rows open Notifications, Help center and Legal', (
    WidgetTester tester,
  ) async {
    await openAccount(tester);

    Future<void> open(String key, Type screen) async {
      final Finder row = find.byKey(ValueKey<String>(key));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('account-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget);
      GoRouter.of(tester.element(find.byType(screen))).pop();
      await tester.pumpAndSettle();
    }

    await open('account-notifications', NotificationPreferencesScreen);
    await open('account-help', HelpCenterScreen);
    await open('account-legal', LegalScreen);
  });

  testWidgets('Legal lists the five policies and the licences', (
    WidgetTester tester,
  ) async {
    await openAccount(tester);
    await push(tester, AppRoutes.legalHub);

    for (final String path in <String>[
      'savestream.online/terms',
      'savestream.online/privacy',
      'savestream.online/acceptable-use',
      'savestream.online/copyright',
      'savestream.online/refund',
    ]) {
      expect(find.text(path), findsOneWidget);
    }
    expect(find.text('Open-source licences'), findsOneWidget);
  });

  testWidgets('Help center search filters the articles locally', (
    WidgetTester tester,
  ) async {
    await openAccount(tester);
    await push(tester, AppRoutes.help);

    expect(find.text('Adding and verifying a channel'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('help-search')),
      'recording fail',
    );
    await tester.pump();
    expect(find.text('Why did a recording fail?'), findsOneWidget);
    expect(find.text('Adding and verifying a channel'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('help-search')),
      'zzz',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('help-no-results')), findsOne);
  });

  testWidgets('cancelling Delete Account keeps the session authenticated', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController();

    await openAccount(tester, session: session);
    await push(tester, AppRoutes.deleteAccount);

    expect(find.text('This can’t be undone.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('delete-account-cancel')),
    );
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(find.byType(AccountScreen), findsOneWidget);
  });

  testWidgets('Pro balance shows as recording time left', (
    WidgetTester tester,
  ) async {
    await openAccount(
      tester,
      overrides: <Override>[
        entitlementRepositoryProvider.overrideWithValue(
          const MockEntitlementRepository(
            MockBehavior(
              scenario: MockScenario.success,
              latency: Duration.zero,
            ),
            state: EntitlementMockState.pro,
          ),
        ),
      ],
    );

    expect(find.text('133 h left'), findsOneWidget);
    final Text email = tester.widget<Text>(find.text('alex@example.com').first);
    expect(email.maxLines, 1);
    expect(email.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the report form posts an abuse report and confirms it', (
    WidgetTester tester,
  ) async {
    final _RecordingReports reports = _RecordingReports();
    tallView(tester);
    await openAccount(
      tester,
      overrides: <Override>[
        reportRepositoryProvider.overrideWithValue(reports),
      ],
    );
    await push(tester, AppRoutes.report);

    // Required fields first.
    await tester.tap(find.byKey(const ValueKey<String>('report-send')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the TikTok username or link.'), findsOneWidget);
    expect(reports.sent, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('report-other')));
    await tester.enterText(
      find.byKey(const ValueKey<String>('report-target')),
      '@my_shop_live',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('report-details')),
      'Recorded my LIVE on Oct 20.',
    );
    await tester.tap(find.byKey(const ValueKey<String>('report-send')));
    await tester.pumpAndSettle();

    final ContentReport sent = reports.sent.single;
    expect(sent.category, ReportCategory.other);
    expect(sent.target, '@my_shop_live');
    expect(sent.email, 'alex@example.com');
    expect(reportRequestBody(sent)['reporter_role'], 'other');
    expect(reportRequestBody(sent)['kind'], 'abuse');
    expect(find.text('Report received'), findsOneWidget);
    expect(find.textContaining('Reference SR-1044'), findsOneWidget);
  });

  testWidgets('copyright notices continue on the web form', (
    WidgetTester tester,
  ) async {
    final _RecordingReports reports = _RecordingReports();
    tallView(tester);
    await openAccount(
      tester,
      overrides: <Override>[
        reportRepositoryProvider.overrideWithValue(reports),
      ],
    );
    await push(tester, AppRoutes.report);
    await tester.tap(find.byKey(const ValueKey<String>('report-copyright')));
    await tester.pumpAndSettle();

    expect(find.text('Continue on the web'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('report-target')), findsNothing);
    expect(reports.sent, isEmpty);
  });

  testWidgets('a report the server wants verified on the web is not faked', (
    WidgetTester tester,
  ) async {
    final _RecordingReports reports = _RecordingReports(needsWeb: true);
    tallView(tester);
    await openAccount(
      tester,
      overrides: <Override>[
        reportRepositoryProvider.overrideWithValue(reports),
      ],
    );
    await push(tester, AppRoutes.report);
    await tester.enterText(
      find.byKey(const ValueKey<String>('report-target')),
      '@someone',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('report-details')),
      'Details',
    );
    await tester.tap(find.byKey(const ValueKey<String>('report-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(reports.sent, hasLength(1));
    expect(find.text('Report received'), findsNothing);
    expect(
      find.text(
        'Please finish your report on savestream.online. It opened in your '
        'browser.',
      ),
      findsOneWidget,
    );
  });
}

class _RecordingReports implements ReportRepository {
  _RecordingReports({this.needsWeb = false});

  final bool needsWeb;
  final List<ContentReport> sent = <ContentReport>[];

  @override
  Future<String> submit(ContentReport report) async {
    sent.add(report);
    if (needsWeb) throw const ReportNeedsWebFormException();
    return 'SR-1044';
  }
}
