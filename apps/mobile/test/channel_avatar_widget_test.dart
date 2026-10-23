// SsV2Avatar: the channel picture over the initials circle, which stays as
// placeholder and fallback.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/widgets/v2/ss_v2_widgets.dart';

import 'screenshots/fake_avatars.dart';

Widget _host(Widget child) => MaterialApp(home: Center(child: child));

void main() {
  late ImageProvider Function(String) appProvider;
  setUp(() => appProvider = SsV2Avatar.imageProvider);
  tearDown(() => SsV2Avatar.imageProvider = appProvider);

  testWidgets('no picture: initials only', (WidgetTester tester) async {
    await tester.pumpWidget(_host(const SsV2Avatar(name: '@my_shop_live')));
    expect(find.text('MS'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('picture over the initials', (WidgetTester tester) async {
    final List<String> loaded = <String>[];
    SsV2Avatar.imageProvider = (String url) {
      loaded.add(url);
      return fakeAvatarProvider(url);
    };
    await tester.pumpWidget(
      _host(const SsV2Avatar(name: '@my_shop_live', imageUrl: fakeAvatarA)),
    );
    expect(loaded, <String>[fakeAvatarA]);
    expect(find.byType(Image), findsOneWidget);
    // The initials stay underneath while it loads.
    expect(find.text('MS'), findsOneWidget);
  });

  testWidgets('a broken picture falls back to the initials', (
    WidgetTester tester,
  ) async {
    SsV2Avatar.imageProvider = (String url) =>
        MemoryImage(Uint8List.fromList(<int>[0, 1, 2, 3]));
    await tester.pumpWidget(
      _host(const SsV2Avatar(name: '@my_shop_live', imageUrl: fakeAvatarB)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('MS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the app loads pictures through the disk cache', () {
    expect(
      SsV2Avatar.imageProvider(fakeAvatarA).runtimeType.toString(),
      'CachedNetworkImageProvider',
    );
  });
}
