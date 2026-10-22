// Renders app screens at the 390×844 artboard size with the bundled fonts.
//
// PNGs are written only when SAVESTREAM_SCREENSHOT_DIR is set, e.g.
//   SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/auth-home \
//     flutter test test/screenshots
// Without it the tests still render every screen and fail on layout errors.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size artboardSize = Size(390, 844);
const double screenshotPixelRatio = 2;
const ValueKey<String> screenshotBoundaryKey = ValueKey<String>(
  'screenshot-boundary',
);

String? get screenshotDir {
  final String? dir = Platform.environment['SAVESTREAM_SCREENSHOT_DIR'];
  return dir == null || dir.isEmpty ? null : dir;
}

Future<void> loadBundledFonts() async {
  Future<void> load(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    for (final String file in files) {
      final Uint8List bytes = File(file).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Plus Jakarta Sans', <String>[
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-Medium.ttf',
    'assets/fonts/PlusJakartaSans-SemiBold.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ]);
  await load('Geist Mono', <String>['assets/fonts/GeistMono-Variable.ttf']);
}

/// Sets a phone-sized view with animations disabled (spinners hold still).
void usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = artboardSize * screenshotPixelRatio;
  tester.view.devicePixelRatio = screenshotPixelRatio;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget screenshotFrame(Widget child) {
  return RepaintBoundary(key: screenshotBoundaryKey, child: child);
}

/// Drops focus (no caret or focus ring, as on the artboards) and settles.
Future<void> settleForCapture(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> captureScreen(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final String? dir = screenshotDir;
  if (dir == null) return;
  final RenderRepaintBoundary boundary = tester.renderObject(
    find.byKey(screenshotBoundaryKey),
  );
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(
      pixelRatio: screenshotPixelRatio,
    );
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    final File file = File('$dir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}
