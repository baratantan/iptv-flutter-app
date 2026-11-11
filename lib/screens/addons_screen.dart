import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/addon_models.dart';

class AddonsScreen extends StatefulWidget {
  const AddonsScreen({super.key});

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // قائمة بكل الكاتالوجات المتاحة (من كل الإضافات)
  List<Map<String, dynamic>> _allCatalogs = [];
  
  // محتوى كل كاتالوج (المفتاح: اسم الكاتالوج، القيمة: قائمة الأفلام)
  Map<String, List<AddonCatalogItem>> _catalogContents = {};

  @override
  void initState() {
    super.initState();
    _loadAllAddonsData();
  }

  Future<void> _loadAllAddonsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addonsJson = prefs.getString('addons_list');

      if (addonsJson == null || addonsJson.isEmpty) {
        setState(() {
          _errorMessage = 'لم يتم إضافة أي إضافة. يرجى إضافتها من الإعدادات.';
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> decoded = json.decode(addonsJson);
      final List<AddonConfig> allAddons = decoded.map((e) => AddonConfig.fromJson(e)).toList();
      
      // تصفية الإضافات النشطة فقط
      final activeAddons = allAddons.where((a) => a.isEnabled).toList();

      if (activeAddons.isEmpty) {
        setState(() {
          _errorMessage = 'لا توجد إضافات نشطة. يرجى تفعيل إضافة واحدة على الأقل.';
          _isLoading = false;
        });
        return;
      }

      // جلب البيانات من كل إضافة نشطة
      List<Map<String, dynamic>> allCatalogs = [];
      Map<String, List<AddonCatalogItem>> catalogContents = {};

      for (var addon in activeAddons) {
        try {
          // 1. جلب manifest.json
          final manifestResponse = await http.get(Uri.parse('${addon.url}/manifest.json'));
          if (manifestResponse.statusCode != 200) {
            continue; // تخطي الإضافة إذا فشلت
          }

          final manifestJson = json.decode(manifestResponse.body);
          final manifest = AddonManifest.fromJson(manifestJson, addon.url);

          // 2. جلب محتوى كل كاتالوج
          for (var catalog in manifest.catalogs) {
            try {
              final catalogUrl = '${addon.url}/catalog/${catalog.type}/${catalog.id}.json';
              final catalogResponse = await http.get(Uri.parse(catalogUrl));

              if (catalogResponse.statusCode == 200) {
                final catalogJson = json.decode(catalogResponse.body);
                final metas = catalogJson['metas'] as List? ?? [];
                
                List<AddonCatalogItem> items = metas
                    .map((m) => AddonCatalogItem.fromJson(m))
                    .toList();

                // إضافة الكاتالوج إلى القائمة
                allCatalogs.add({
                  'name': catalog.name,
                  'addonName': manifest.name,
                  'type': catalog.type,
                  'id': catalog.id,
                });

                // تخزين محتوى الكاتالوج
                final key = '${manifest.name} - ${catalog.name}';
                catalogContents[key] = items;
              }
            } catch (e) {
              // تخطي الكاتالوج إذا فشل
            }
          }
        } catch (e) {
          // تخطي الإضافة إذا فشلت
        }
      }

      setState(() {
        _allCatalogs = allCatalogs;
        _catalogContents = catalogContents;
        _isLoading = false;
        if (allCatalogs.isEmpty) {
          _errorMessage = 'لم يتم العثور على محتوى في الإضافات النشطة.';
        }
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playItem(AddonCatalogItem item) async {
    // مؤقتاً: نعرض رسالة. سنقوم بتشغيل الفيديو في المرحلة التالية
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سيتم تشغيل: ${item.name} (قريباً)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    // تجميع كل الأفلام من كل الكاتالوجات للبانر
    List<AddonCatalogItem> allItems = [];
    _catalogContents.forEach((key, list) => allItems.addAll(list));
    final bannerItems = allItems.take(6).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: CustomScrollView(
        slivers: [
          // 1. البانر المتحرك
          SliverToBoxAdapter(
            child: SizedBox(
              height: 320,
              child: PageView.builder(
                itemCount: bannerItems.length,
                itemBuilder: (context, index) {
                  final item = bannerItems[index];
                  return GestureDetector(
                    onTap: () => _playItem(item),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(item.poster ?? ''),
                          fit: BoxFit.cover,
                          onError: (e, s) {},
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _playItem(item),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('تشغيل'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5238),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. الشرائط الأفقية لكل كاتالوج
          ..._catalogContents.entries.map((entry) {
            return SliverToBoxAdapter(
              child: _buildHorizontalSection(entry.key, entry.value),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<AddonCatalogItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => _playItem(item),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: (item.poster != null && item.poster!.isNotEmpty)
                              ? Image.network(item.poster!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie))
                              : const Icon(Icons.movie),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
