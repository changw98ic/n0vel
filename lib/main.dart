import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/config/app_env.dart';
import 'core/services/writer_guidance_loader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.load();
  final guidanceLoader = WriterGuidanceLoader();
  final guidanceValidation = await guidanceLoader.validateIndex();
  if (!guidanceValidation.isValid || guidanceValidation.warnings.isNotEmpty) {
    debugPrint('[WriterGuidance] $guidanceValidation');
  }
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
