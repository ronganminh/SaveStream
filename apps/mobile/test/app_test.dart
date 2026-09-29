import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';

void main() {
  testWidgets('boots the SaveStream placeholder app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: AppConfig(
          environment: AppEnvironment.local,
          apiBaseUrl: Uri.parse('http://localhost:8000'),
        ),
      ),
    );

    expect(find.text('SaveStream'), findsOneWidget);
    expect(find.text('Flutter mobile foundation is ready.'), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
  });
}
