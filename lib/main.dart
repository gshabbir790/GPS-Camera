import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/app_settings.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppSettings.instance.load();
  runApp(const GpsCameraApp());
}

class GpsCameraApp extends StatelessWidget {
  const GpsCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Camera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFC400),
        // انگریزی کے لیے ڈیفالٹ فونٹ، اردو حروف کے لیے نستعلیق
        fontFamilyFallback: const ['NotoNastaliqUrdu'],
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const CameraScreen(),
    );
  }
}
