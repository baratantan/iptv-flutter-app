import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'package:http/http.dart' as http;
import 'package:airo_m3u_parser/m3u_parser.dart';
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
      // التصحيح: استخدام parseM3u
      final playlist = await parseM3u(m3uContent);
      if (playlist.channels.isEmpty) throw Exception('لم يتم العثور على قنوات في ملف M3U');
      
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
        appBar: AppBar(
          leading: Navigator.canPop(context) ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()) : null,
          title: const Text('إعداد الاتصال'),
          backgroundColor: const Color(0xFF111827),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF5238),
            labelColor: Color(0xFFFF5238),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Xtream', icon: Icon(Icons.cloud)),
              Tab(text: 'M3U', icon: Icon(Icons.playlist_play)),
            ],
          ),
        ),
        body: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))) : TabBarView(children: [_buildXtreamTab(), _buildM3uTab()]),
      ),
    );
  }

  Widget _buildXtreamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.settings_input_antenna, size: 80, color: Color(0xFFFF5238)),
          const SizedBox(height: 32),
          TextField(controller: _serverController, decoration: const InputDecoration(labelText: 'رابط السيرفر (Server URL)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)), textDirection: TextDirection.ltr),
          const SizedBox(height: 16),
          TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'اسم المستخدم (Username)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)), textDirection: TextDirection.ltr),
          const SizedBox(height: 16),
          TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (Password)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)), textDirection: TextDirection.ltr),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _saveXtreamAndConnect, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5238), foregroundColor: Colors.white), child: const Text('اتصال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildM3uTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.playlist_play, size: 80, color: Color(0xFFFF5238)),
          const SizedBox(height: 32),
          TextField(controller: _m3uUrlController, decoration: const InputDecoration(labelText: 'رابط قائمة M3U (URL)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)), textDirection: TextDirection.ltr),
          const SizedBox(height: 16),
          const Text('أو الصق محتوى M3U هنا:', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(controller: _m3uTextController, maxLines: 5, decoration: const InputDecoration(hintText: '#EXTM3U...', border: OutlineInputBorder()), textDirection: TextDirection.ltr),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _saveM3uAndConnect, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5238), foregroundColor: Colors.white), child: const Text('تحميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}
