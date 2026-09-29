import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  testWidgets('boots the Phase 1 component gallery in English', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pumpAndSettle();

    expect(find.text('SaveStream'), findsOneWidget);
    expect(find.text('Design system'), findsOneWidget);
    expect(find.text('Environment: LOCAL'), findsOneWidget);
    expect(find.text('Primary action'), findsOneWidget);
  });

  testWidgets('switches locale from English to Vietnamese at runtime', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), settings: settings),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design system'), findsOneWidget);

    settings.setLocale(const Locale('vi'));
    await tester.pumpAndSettle();

    expect(find.text('Hệ thống thiết kế'), findsOneWidget);
    expect(find.text('Giao diện'), findsOneWidget);
  });

  testWidgets('switches theme mode at runtime', (WidgetTester tester) async {
    final AppSettingsController settings = AppSettingsController();

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), settings: settings),
    );
    await tester.pumpAndSettle();

    settings.setThemeMode(ThemeMode.dark);
    await tester.pump();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}
