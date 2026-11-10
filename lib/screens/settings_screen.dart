import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _sourceType = 'غير محدد';

  @override
  void initState() {
    super.initState();
    _loadCurrentSource();
  }

  Future<void> _loadCurrentSource() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString('source_type') ?? '';
    if (mounted) {
      setState(() {
        if (type == 'xtream') {
          _sourceType = 'Xtream Codes';
        } else if (type == 'm3u') {
          _sourceType = 'M3U Playlist';
        } else {
          _sourceType = 'غير محدد';
        }
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('source_type');
    await prefs.remove('xtream_server');
    await prefs.remove('xtream_username');
    await prefs.remove('xtream_password');
    await prefs.remove('m3u_content');
    await prefs.remove('m3u_url');
    await prefs.remove('addon_url'); // مسح رابط الإضافة أيضاً

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _editAddonUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString('addon_url') ?? '';
    final controller = TextEditingController(text: currentUrl);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('رابط الإضافة', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://example.com/manifest.json',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF5238))),
          ),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ', style: TextStyle(color: Color(0xFFFF5238))),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await prefs.setString('addon_url', result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ رابط الإضافة بنجاح')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم الاشتراك
          const Text(
            'الاشتراك',
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFFFF5238)),
                  title: const Text('مصدر المحتوى الحالي', style: TextStyle(color: Colors.white)),
                  subtitle: Text(_sourceType, style: const TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFFFF5238)),
                  title: const Text('تغيير بيانات الاشتراك', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('تسجيل الخروج (مسح البيانات)', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1F2937),
                        title: const Text('تأكيد', style: TextStyle(color: Colors.white)),
                        content: const Text('هل أنت متأكد من مسح جميع البيانات؟', style: TextStyle(color: Colors.grey)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('مسح', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _logout();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // قسم الإضافات (جديد)
          const Text(
            'الإضافات',
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.extension, color: Color(0xFFFF5238)),
                  title: const Text('إدارة الإضافة', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('أضف رابط الإضافة (Addon URL)', style: TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  onTap: _editAddonUrl,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // قسم حول التطبيق
          const Text(
            'حول التطبيق',
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.apps, color: Color(0xFFFF5238)),
                  title: const Text('اسم التطبيق', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Player Pro', style: TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  leading: const Icon(Icons.numbers, color: Color(0xFFFF5238)),
                  title: const Text('الإصدار', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
