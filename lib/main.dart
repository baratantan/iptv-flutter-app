import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  try {
    // نسخ ملف الشهادة إلى المكان الذي تتوقعه المكتبة
    final certDir = Directory('${Directory.systemTemp.path}/libtorrent_flutter');
    await certDir.create(recursive: true);
    final certFile = File('${certDir.path}/cacert.pem');
    
    if (!await certFile.exists()) {
      final byteData = await rootBundle.load('assets/cacert.pem');
      await certFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    }

    // الآن يمكننا تهيئة المكتبة بأمان
    await LibtorrentFlutter.init();
    print('Torrent engine initialized successfully');
  } catch (e) {
    // إذا فشلت التهيئة، نطبع الخطأ ونكمل (بدون تورنت)
    print('Failed to initialize torrent engine: $e');
  }

  runApp(const IptvApp());
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Player Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF5238),
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5238),
          secondary: Color(0xFFFF5238),
          surface: Color(0xFF111827),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
