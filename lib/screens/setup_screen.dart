import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'package:http/http.dart' as http;
import 'package:airo_m3u_parser/m3u_parser.dart' as airo_m3u_parser;
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _m3uUrlController = TextEditingController();
  final _m3uTextController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveXtreamAndConnect() async {
    if (_serverController.text.isEmpty || _usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء ملء جميع الحقول')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final portal = XtreamPortal.parse(_serverController.text.trim());
      final credentials = XtreamCredentials(username: _usernameController.text.trim(), password: _passwordController.text.trim());
      final client = XtreamClient(portal, credentials);
      final accountInfo = await client.getUserAndServerInfo();
      if (accountInfo != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('source_type', 'xtream');
        await prefs.setString('xtream_server', _serverController.text.trim());
        await prefs.setString('xtream_username', _usernameController.text.trim());
        await prefs.setString('xtream_password', _passwordController.text.trim());
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        throw Exception('بيانات الدخول غير صحيحة');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاتصال: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveM3uAndConnect() async {
    String content = _m3uTextController.text.trim();
    String url = _m3uUrlController.text.trim();
    if (content.isEmpty && url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط M3U أو لصق النص')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      String m3uContent = content;
      if (m3uContent.isEmpty) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) throw Exception('فشل تحميل الملف (HTTP ${response.statusCode})');
        m3uContent = response.body;
      }
      final playlist = await airo_m3u_parser.parseM3uAsync(m3uContent);
      if (playlist.entries.isEmpty) throw Exception('لم يتم العثور على قنوات في ملف M3U');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('source_type', 'm3u');
      await prefs.setString('m3u_content', m3uContent);
      await prefs.setString('m3u_url', url);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحليل M3U: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A0A0A), // أحمر داكن جداً
                const Color(0xFF0B0E14), // أسود
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // الشعار
                const SizedBox(height: 40),
                Image.asset(
                  'app_icon.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Player Pro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  'مشغل احترافي',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 24),
                
                // التبويبات
                const TabBar(
                  indicatorColor: Color(0xFFFF5238),
                  labelColor: Color(0xFFFF5238),
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Xtream', icon: Icon(Icons.cloud)),
                    Tab(text: 'M3U', icon: Icon(Icons.playlist_play)),
                  ],
                ),
                
                // محتوى التبويبات
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238)))
                      : TabBarView(
                          children: [
                            _buildXtreamTab(),
                            _buildM3uTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildXtreamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextField(
            controller: _serverController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'رابط السيرفر (Server URL)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.link, color: Color(0xFFFF5238)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF5238)),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'اسم المستخدم (Username)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.person, color: Color(0xFFFF5238)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF5238)),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'كلمة المرور (Password)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFFFF5238)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF5238)),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _saveXtreamAndConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5238),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
                shadowColor: const Color(0xFFFF5238).withOpacity(0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login),
                  SizedBox(width: 8),
                  Text('اتصال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildM3uTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextField(
            controller: _m3uUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'رابط قائمة M3U (URL)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.link, color: Color(0xFFFF5238)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF5238)),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 16),
          const Text(
            'أو الصق محتوى M3U هنا:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _m3uTextController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '#EXTM3U...',
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF5238)),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _saveM3uAndConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5238),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
                shadowColor: const Color(0xFFFF5238).withOpacity(0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Text('تحميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
