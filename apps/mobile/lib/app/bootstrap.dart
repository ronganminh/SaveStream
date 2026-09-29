import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import 'savestream_app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config = AppConfig.fromEnvironment();
  runApp(SaveStreamApp(config: config));
}
