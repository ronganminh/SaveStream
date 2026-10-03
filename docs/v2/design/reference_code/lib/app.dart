import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/ss_theme.dart';

class SaveStreamApp extends StatelessWidget {
  const SaveStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SaveStream',
      debugShowCheckedModeBanner: false,
      theme: ssTheme(Brightness.light),
      darkTheme: ssTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      // X01–X03: cho phép tới 200%, timer tự cap 1.5× trong widget.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 2.0)),
          child: child!,
        );
      },
    );
  }
}
