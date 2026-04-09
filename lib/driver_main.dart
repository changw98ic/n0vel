import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';

void main() async {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1440, 920),
      minimumSize: Size(1180, 760),
      center: true,
      backgroundColor: Color(0xFFF6F4EF),
      title: '写作助手',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await ScreenUtil.ensureScreenSize();
  runApp(
    ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      builder: (context, child) => const WritingAssistantApp(),
    ),
  );
}
