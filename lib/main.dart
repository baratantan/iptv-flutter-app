import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  // تهيئة محرك التورنت (ضروري ليعمل البث عبر التورنت)
  await LibtorrentFlutter.init();

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
