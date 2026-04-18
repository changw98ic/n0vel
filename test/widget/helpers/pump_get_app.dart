import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/app/theme.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

const _windowManagerChannel = MethodChannel('window_manager');

Future<void> pumpGetApp(
  WidgetTester tester, {
  Widget? home,
  List<GetPage<dynamic>>? getPages,
  String? initialRoute,
  Bindings? initialBinding,
  Size surfaceSize = const Size(1440, 900),
}) async {
  assert(home != null || initialRoute != null);

  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_windowManagerChannel, (call) async {
        switch (call.method) {
          case 'isFocused':
          case 'isMaximized':
          case 'isMinimized':
          case 'isFullScreen':
          case 'isAlwaysOnTop':
          case 'isVisibleOnAllWorkspaces':
          case 'isResizable':
          case 'isPreventClose':
            return false;
          case 'getTitleBarHeight':
            return 0.0;
          default:
            return null;
        }
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
  });

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      builder: (context, child) => GetMaterialApp(
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
        themeMode: ThemeMode.light,
        initialBinding: initialBinding,
        home: home,
        getPages: getPages ?? const [],
        initialRoute: initialRoute,
      ),
    ),
  );

  await tester.pump();
}
