import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../l10n/app_localizations.dart';
import '../core/bindings/initial_binding.dart';
import '../core/config/app_pages.dart';
import 'theme.dart';

class WritingAssistantApp extends StatelessWidget {
  const WritingAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '写作助手',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      fallbackLocale: const Locale('zh', 'CN'),
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        ...S.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialBinding: InitialBinding(),
      initialRoute: '/',
      getPages: getPages,
    );
  }
}
