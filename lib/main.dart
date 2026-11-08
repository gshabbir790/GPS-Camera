import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/strings.dart';
import 'models/app_settings.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await AppSettings.instance.load();
  runApp(const GpsCameraApp());
}

class GpsCameraApp extends StatelessWidget {
  const GpsCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        title: 'GPS Camera',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFFFFC400),
          // اردو حروف کے لیے نستعلیق فونٹ
          fontFamilyFallback: const ['NotoNastaliqUrdu'],
        ),
        builder: (context, child) => Directionality(
          textDirection: S.ur ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
