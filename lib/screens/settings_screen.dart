import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/addon_models.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _sourceType = 'غير محدد';
  List<AddonConfig> _addons = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString('source_type') ?? '';
    final addonsJson = prefs.getString('addons_list');

    List<AddonConfig> loadedAddons = [];
    if (addonsJson != null && addonsJson.isNotEmpty) {
      final List<dynamic> decoded = json.decode(addonsJson);
      loadedAddons = decoded.map((e) => AddonConfig.fromJson(e)).toList();
    }

    if (mounted) {
      setState(() {
        _sourceType = type == 'xtream' ? 'Xtream Codes' : (type == 'm3u' ? 'M3U Playlist' : 'غير محدد');
        _addons = loadedAddons;
      });
    }
  }

  Future<void> _saveAddons(List<AddonConfig> addons) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(addons.map((e) => e.toJson()).toList());
    await prefs.setString('addons_list', encoded);
    setState(() {
      _addons = addons;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _addNewAddon() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('إضافة جديدة', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اسم الإضافة (مثال: Cinemeta)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF5238))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الرابط (Addon URL)',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'https://v3-cinemeta.strem.io',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF5238))),
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إضافة', style: TextStyle(color: Color(0xFFFF5238))),
          ),
        ],
      ),
    );

    if (result == true && urlController.text.trim().isNotEmpty) {
      String url = urlController.text.trim();
      // إزالة manifest.json إذا كتبه المستخدم
      if (url.endsWith('/manifest.json')) {
        url = url.substring(0, url.length - '/manifest.json'.length);
      }
      // إزالة الشرطة المائلة في النهاية
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      final newAddon = AddonConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim().isEmpty ? 'إضافة جديدة' : nameController.text.trim(),
        url: url,
        isEnabled: true,
      );

      await _saveAddons([..._addons, newAddon]);
    }
  }

  Future<void> _removeAddon(String id) async {
    final updatedAddons = _addons.where((a) => a.id != id).toList();
    await _saveAddons(updatedAddons);
  }

  Future<void> _toggleAddon(String id, bool isEnabled) async {
    final updatedAddons = _addons.map((a) {
      if (a.id == id) {
        return AddonConfig(id: a.id, name: a.name, url: a.url, isEnabled: isEnabled);
      }
      return a;
    }).toList();
    await _saveAddons(updatedAddons);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('الإعدادات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFFF5238)),
            onPressed: _addNewAddon,
            tooltip: 'إضافة إضافة جديدة',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم الاشتراك
          const Text('الاشتراك', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
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
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetupScreen()));
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
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('مسح', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) await _logout();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // قسم الإضافات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإضافات', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _addNewAddon,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFFF5238)),
                label: const Text('إضافة', style: TextStyle(color: Color(0xFFFF5238))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_addons.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
              child: const Center(
                child: Text('لم يتم إضافة أي إضافة. اضغط على زر + لإضافة إضافة.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._addons.map((addon) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Switch(
                      value: addon.isEnabled,
                      onChanged: (value) => _toggleAddon(addon.id, value),
                      activeColor: const Color(0xFFFF5238),
                    ),
                    title: Text(addon.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(addon.url, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeAddon(addon.id),
                    ),
                  ),
                )),

          const SizedBox(height: 24),

          // قسم حول التطبيق
          const Text('حول التطبيق', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
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
