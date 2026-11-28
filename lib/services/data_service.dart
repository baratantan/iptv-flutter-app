import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';

// نموذج لبيانات الإضافة المخزنة مؤقتاً
class AddonCache {
  final String addonUrl;
  final String addonName;
  final List<Map<String, dynamic>> catalogs;
  final DateTime timestamp;

  AddonCache({
    required this.addonUrl,
    required this.addonName,
    required this.catalogs,
    required this.timestamp,
  });
}

class DataService {
  static final http.Client _client = http.Client();
  
  // تخزين مؤقت لبيانات Xtream
  static List<XtLiveChannel>? _cachedLiveChannels;
  static List<XtVodItem>? _cachedMovies;
  static List<XtSeriesItem>? _cachedSeries;
  static List<XtCategory>? _cachedVodCategories;
  static List<XtCategory>? _cachedSeriesCategories;
  static List<XtCategory>? _cachedLiveCategories;
  static DateTime? _xtreamCacheTime;

  // تخزين مؤقت لبيانات الإضافات
  static final Map<String, AddonCache> _addonCache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  // ============ Xtream ============

  static Future<void> loadXtreamData({
    required String server,
    required String username,
    required String password,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _xtreamCacheTime != null) {
      final age = DateTime.now().difference(_xtreamCacheTime!);
      if (age < _cacheDuration) {
        return;
      }
    }

    final portal = XtreamPortal.parse(server);
    final credentials = XtreamCredentials(username: username, password: password);
    final client = XtreamClient(portal, credentials);

    final results = await Future.wait([
      client.getLiveStreams(),
      client.getVodStreams(),
      client.getSeries(),
      client.getVodCategories(),
      client.getSeriesCategories(),
      client.getLiveCategories(),
    ]);

    _cachedLiveChannels = await compute(_parseChannels, results[0]);
    _cachedMovies = await compute(_parseMovies, results[1]);
    _cachedSeries = await compute(_parseSeries, results[2]);
    _cachedVodCategories = await compute(_parseCategories, results[3]);
    _cachedSeriesCategories = await compute(_parseCategories, results[4]);
    _cachedLiveCategories = await compute(_parseCategories, results[5]);
    _xtreamCacheTime = DateTime.now();
  }

  static List<XtLiveChannel>? get liveChannels => _cachedLiveChannels;
  static List<XtVodItem>? get movies => _cachedMovies;
  static List<XtSeriesItem>? get series => _cachedSeries;
  static List<XtCategory>? get vodCategories => _cachedVodCategories;
  static List<XtCategory>? get seriesCategories => _cachedSeriesCategories;
  static List<XtCategory>? get liveCategories => _cachedLiveCategories;

  // ============ الإضافات ============

  static Future<AddonCache?> loadAddonData(String addonUrl, String addonName, {bool forceRefresh = false}) async {
    if (!forceRefresh && _addonCache.containsKey(addonUrl)) {
      final cached = _addonCache[addonUrl]!;
      final age = DateTime.now().difference(cached.timestamp);
      if (age < _cacheDuration) {
        return cached;
      }
    }

    try {
      final manifestResponse = await _client.get(Uri.parse('$addonUrl/manifest.json'));
      if (manifestResponse.statusCode != 200) return null;

      final manifestJson = json.decode(manifestResponse.body);
      final catalogs = manifestJson['catalogs'] as List? ?? [];

      List<Map<String, dynamic>> allCatalogs = [];

      for (var catalog in catalogs) {
        try {
          // إضافة معامل اللغة (ar-SA) لطلب الكتالوج
          final catalogUrl = '$addonUrl/catalog/${catalog['type']}/${catalog['id']}.json?lang=ar-SA';
          final catalogResponse = await _client.get(Uri.parse(catalogUrl));

          if (catalogResponse.statusCode == 200) {
            final catalogJson = json.decode(catalogResponse.body);
            final metas = catalogJson['metas'] as List? ?? [];
            
            final items = await compute(_parseAddonItems, metas);
            
            allCatalogs.add({
              'name': catalog['name'] ?? 'بدون اسم',
              'type': catalog['type'] ?? 'movie',
              'items': items,
            });
          }
        } catch (e) {
          // تخطي
        }
      }

      final cache = AddonCache(
        addonUrl: addonUrl,
        addonName: addonName,
        catalogs: allCatalogs,
        timestamp: DateTime.now(),
      );
      
      _addonCache[addonUrl] = cache;
      return cache;
    } catch (e) {
      return null;
    }
  }

  static void clearCache() {
    _cachedLiveChannels = null;
    _cachedMovies = null;
    _cachedSeries = null;
    _cachedVodCategories = null;
    _cachedSeriesCategories = null;
    _cachedLiveCategories = null;
    _xtreamCacheTime = null;
    _addonCache.clear();
  }
}

// دوال التحليل في الخلفية
List<XtLiveChannel> _parseChannels(dynamic data) {
  return (data as List).cast<XtLiveChannel>();
}

List<XtVodItem> _parseMovies(dynamic data) {
  return (data as List).cast<XtVodItem>();
}

List<XtSeriesItem> _parseSeries(dynamic data) {
  return (data as List).cast<XtSeriesItem>();
}

List<XtCategory> _parseCategories(dynamic data) {
  return (data as List).cast<XtCategory>();
}

List<Map<String, dynamic>> _parseAddonItems(List<dynamic> metas) {
  return metas.map((m) => {
    'id': m['id'] ?? '',
    'name': m['name'] ?? 'بدون اسم',
    'poster': m['poster'],
    'description': m['description'],
  }).toList();
}
