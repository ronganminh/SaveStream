// Renders app screens at the 390×844 artboard size with the bundled fonts.
//
// PNGs are written only when SAVESTREAM_SCREENSHOT_DIR is set, e.g.
//   SAVESTREAM_SCREENSHOT_DIR=../../docs/mobile-v2/screens/auth-home \
//     flutter test test/screenshots
// Without it the tests still render every screen and fail on layout errors.
//
// On the Android emulator (integration_test/auth_home_screenshots_test.dart)
// pass --dart-define=SAVESTREAM_SCREENSHOT_DIR=device: each PNG is printed as
// base64 lines (`SS-SCREEN <name> <chunk>`) because `flutter test` uninstalls
// the app afterwards; tool/decode_screens.py rebuilds them from the log.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/widgets/v2/ss_v2_widgets.dart';

import 'fake_avatars.dart';

const Size artboardSize = Size(390, 844);
const double screenshotPixelRatio = 2;
const ValueKey<String> screenshotBoundaryKey = ValueKey<String>(
  'screenshot-boundary',
);

const String _definedScreenshotDir = String.fromEnvironment(
  'SAVESTREAM_SCREENSHOT_DIR',
);

bool get _printToLog => _definedScreenshotDir == 'device';

String? get screenshotDir {
  if (_printToLog) return 'device';
  if (_definedScreenshotDir.isNotEmpty) return _definedScreenshotDir;
  final String? dir = Platform.environment['SAVESTREAM_SCREENSHOT_DIR'];
  return dir == null || dir.isEmpty ? null : dir;
}

Future<void> loadBundledFonts() async {
  // On a device the fonts come from the app bundle.
  if (Platform.isAndroid || Platform.isIOS) return;
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
/// [size] is for taller artboards (a scrolled list drawn in full).
void usePhoneView(WidgetTester tester, {Size size = artboardSize}) {
  tester.view.physicalSize = size * screenshotPixelRatio;
  tester.view.devicePixelRatio = screenshotPixelRatio;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  // Channel pictures come from local stand-ins (no network in tests).
  final ImageProvider Function(String) appProvider = SsV2Avatar.imageProvider;
  SsV2Avatar.imageProvider = fakeAvatarProvider;
  addTearDown(() => SsV2Avatar.imageProvider = appProvider);
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

/// Image decoding is real async work the test clock doesn't run: decode the
/// in-memory pictures on screen (stand-in avatars) before drawing them.
Future<void> _decodeLocalImages(WidgetTester tester) async {
  final List<Element> images = find
      .byWidgetPredicate((Widget w) => w is Image && w.image is MemoryImage)
      .evaluate()
      .toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    for (final Element element in images) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

Future<void> captureScreen(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final String? dir = screenshotDir;
  if (dir == null) return;
  await _decodeLocalImages(tester);
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
    if (_printToLog) {
      // Inside a test, print() travels to the host as VM Service extension
      // events over the emulator's single adb connection. A whole PNG sent
      // in one burst (150–250 KB) can overrun adbd while the emulator is
      // busy ("host-N: connection terminated: write failed"): adb drops the
      // transport, the VM Service goes with it and every test in the file
      // reports "did not complete". Pause between batches so it drains.
      final String data = base64Encode(png!.buffer.asUint8List());
      int lines = 0;
      for (int i = 0; i < data.length; i += 800) {
        // ignore: avoid_print
        print(
          'SS-SCREEN $name ${data.substring(i, math.min(i + 800, data.length))}',
        );
        if (++lines % 16 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
      }
      return;
    }
    final File file = File('$dir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}
