import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
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
  bool _isLoading = false;

  Future<void> _saveAndConnect() async {
    if (_serverController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع الحقول')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // الطريقة الصحيحة: إنشاء Portal و Credentials أولاً
      final portal = XtreamPortal.parse(_serverController.text.trim());
      final credentials = XtreamCredentials(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // تمرير المعاملات الموضعية (portal, credentials)
      final client = XtreamClient(portal, credentials);

      // التحقق من صحة البيانات
      final accountInfo = await client.getUserAndServerInfo();

      if (accountInfo != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('xtream_server', _serverController.text.trim());
        await prefs.setString('xtream_username', _usernameController.text.trim());
        await prefs.setString('xtream_password', _passwordController.text.trim());

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        throw Exception('بيانات الدخول غير صحيحة');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الاتصال: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد الاتصال'),
        backgroundColor: const Color(0xFF111827),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_input_antenna, size: 80, color: Color(0xFFFF5238)),
            const SizedBox(height: 32),
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: 'رابط السيرفر (Server URL)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم (Username)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور (Password)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5238),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('اتصال', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
