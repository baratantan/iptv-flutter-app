import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import '../models/addon_models.dart';
import '../services/data_service.dart';
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
  bool _isRefreshing = false;

  // تفاصيل الاشتراك
  String? _expirationDate;
  String? _accountStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSubscriptionInfo();
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

  // جلب تفاصيل الاشتراك من السيرفر
  Future<void> _loadSubscriptionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sourceType = prefs.getString('source_type');
      if (sourceType != 'xtream') return;

      final server = prefs.getString('xtream_server') ?? '';
      final username = prefs.getString('xtream_username') ?? '';
      final password = prefs.getString('xtream_password') ?? '';

      if (server.isEmpty) return;

      final portal = XtreamPortal.parse(server);
      final credentials = XtreamCredentials(username: username, password: password);
      final client = XtreamClient(portal, credentials);

      final info = await client.getUserAndServerInfo();
      
      if (mounted) {
        setState(() {
          // الخاصية الصحيحة هي info.user وليس info.userInfo
          _expirationDate = info.user?.expiresAt?.toString();
          // الخاصية الصحيحة هي active (bool) وليس status
          _accountStatus = (info.user?.active == true) ? 'نشط' : 'غير نشط';
        });
      }
    } catch (e) {
      debugPrint('Failed to load subscription info: $e');
    }
  }

  // تحديث بيانات القنوات والأفلام
  Future<void> _refreshPlaylist() async {
    setState(() => _isRefreshing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('xtream_server') ?? '';
      final username = prefs.getString('xtream_username') ?? '';
      final password = prefs.getString('xtream_password') ?? '';

      if (server.isEmpty) throw Exception('لا يوجد بيانات اتصال');

      // إجبار التحديث في DataService
      await DataService.loadXtreamData(
        server: server,
        username: username,
        password: password,
        forceRefresh: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث القنوات والأفلام بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحديث: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // مسح الذاكرة المؤقتة
  Future<void> _clearCache() async {
    DataService.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح الذاكرة المؤقتة')),
      );
    }
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
                labelText: 'اسم الإضافة',
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
      if (url.endsWith('/manifest.json')) {
        url = url.substring(0, url.length - '/manifest.json'.length);
      }
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      final newAddon = AddonConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim().isEmpty ? 'إضافة جديدة' : nameController.text.trim(),
        url: url,
        isEnabled: true,
      );

      final updatedAddons = [..._addons, newAddon];
      await _saveAddons(updatedAddons);
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ قسم الاشتراك ============
          const Text('الاشتراك', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFFFF5238)),
                  title: const Text('مصدر المحتوى الحالي', style: TextStyle(color: Colors.white)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_sourceType, style: const TextStyle(color: Colors.grey)),
                      if (_expirationDate != null)
                        Text(
                          'تاريخ الانتهاء: $_expirationDate',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      if (_accountStatus != null)
                        Text(
                          'حالة الحساب: $_accountStatus',
                          style: TextStyle(
                            color: _accountStatus == 'نشط' ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  leading: _isRefreshing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Color(0xFFFF5238), strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Color(0xFFFF5238)),
                  title: const Text('تحديث القنوات والأفلام', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('إعادة جلب البيانات من السيرفر', style: TextStyle(color: Colors.grey)),
                  onTap: _isRefreshing ? null : _refreshPlaylist,
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

          // ============ قسم الإضافات ============
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
                child: Text('لم يتم إضافة أي إضافة.', style: TextStyle(color: Colors.grey)),
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

          // ============ قسم إعدادات المشغل ============
          const Text('إعدادات المشغل', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.speed, color: Color(0xFFFF5238)),
                  title: const Text('تسريع العتاد (Hardware Acceleration)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('مفعّل افتراضياً', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: Switch(
                    value: true,
                    onChanged: (value) {},
                    activeColor: const Color(0xFFFF5238),
                  ),
                ),
                const Divider(height: 1, color: Colors.grey),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Color(0xFFFF5238)),
                  title: const Text('مسح الذاكرة المؤقتة', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('مسح البيانات المحملة مؤقتاً', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: _clearCache,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ============ قسم حول التطبيق ============
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
