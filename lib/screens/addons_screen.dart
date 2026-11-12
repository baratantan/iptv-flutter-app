import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/addon_models.dart';
import '../services/data_service.dart';
import 'player_screen.dart';

class AddonsScreen extends StatefulWidget {
  const AddonsScreen({super.key});

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, List<Map<String, dynamic>>> _catalogContents = {};
  List<Map<String, dynamic>> _allMovies = [];
  List<Map<String, dynamic>> _allSeries = [];

  Map<String, String> _itemToAddonUrl = {};
  Map<String, String> _itemToType = {};

  final PageController _pageController = PageController(viewportFraction: 1.0);
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  late TabController _tabController;

  // للبحث
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay(List<Map<String, dynamic>> bannerItems) {
    _bannerTimer?.cancel();
    if (bannerItems.isEmpty) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        if (_currentBannerIndex < bannerItems.length - 1) {
          _currentBannerIndex++;
        } else {
          _currentBannerIndex = 0;
        }
        _pageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    });
  }

  Future<void> _loadData() async {
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
      final activeAddons = allAddons.where((a) => a.isEnabled).toList();

      if (activeAddons.isEmpty) {
        setState(() {
          _errorMessage = 'لا توجد إضافات نشطة.';
          _isLoading = false;
        });
        return;
      }

      Map<String, List<Map<String, dynamic>>> catalogContents = {};
      List<Map<String, dynamic>> allMovies = [];
      List<Map<String, dynamic>> allSeries = [];
      Map<String, String> itemToAddonUrl = {};
      Map<String, String> itemToType = {};

      for (var addon in activeAddons) {
        final cache = await DataService.loadAddonData(addon.url, addon.name);
        if (cache == null) continue;

        for (var catalog in cache.catalogs) {
          final catalogName = catalog['name'] as String;
          final catalogType = catalog['type'] as String;
          final items = catalog['items'] as List<Map<String, dynamic>>;

          final key = '${cache.addonName} - $catalogName';
          catalogContents[key] = items;

          for (var item in items) {
            itemToAddonUrl[item['id']] = addon.url;
            itemToType[item['id']] = catalogType;

            if (catalogType == 'movie') {
              allMovies.add(item);
            } else if (catalogType == 'series') {
              allSeries.add(item);
            }
          }
        }
      }

      setState(() {
        _catalogContents = catalogContents;
        _allMovies = allMovies;
        _allSeries = allSeries;
        _itemToAddonUrl = itemToAddonUrl;
        _itemToType = itemToType;
        _isLoading = false;
        if (catalogContents.isEmpty) {
          _errorMessage = 'لم يتم العثور على محتوى في الإضافات النشطة.';
        }
      });

      List<Map<String, dynamic>> bannerItems = [];
      catalogContents.forEach((key, list) => bannerItems.addAll(list));
      _startBannerAutoPlay(bannerItems.take(6).toList());

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playItem(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final addonUrl = _itemToAddonUrl[id];
    final type = _itemToType[id] ?? 'movie';

    if (addonUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على رابط الإضافة')),
      );
      return;
    }

    if (type == 'movie') {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1F2937),
        isScrollControlled: true,
        builder: (context) => _buildStreamsSheet(addonUrl, item, 'movie'),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1F2937),
        isScrollControlled: true,
        builder: (context) => _buildEpisodesSheet(addonUrl, item),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEpisodes(String addonUrl, Map<String, dynamic> series) async {
    final metaUrl = '$addonUrl/meta/series/${series['id']}.json';
    final response = await http.get(Uri.parse(metaUrl));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب حلقات المسلسل (HTTP ${response.statusCode})');
    }

    final jsonData = json.decode(response.body);
    final videos = jsonData['meta']?['videos'] as List? ?? [];

    return videos.map<Map<String, dynamic>>((v) => {
      'id': v['id'] ?? '',
      'title': v['title'] ?? v['name'] ?? 'حلقة',
      'season': v['season'] ?? 0,
      'episode': v['episode'] ?? 0,
    }).toList();
  }

  Widget _buildEpisodesSheet(String addonUrl, Map<String, dynamic> series) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchEpisodes(addonUrl, series),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))));
        }
        if (snapshot.hasError) {
          return SizedBox(height: 200, child: Center(child: Text('فشل: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
        }

        final episodes = snapshot.data ?? [];
        if (episodes.isEmpty) {
          return const SizedBox(height: 200, child: Center(child: Text('لا توجد حلقات متاحة', style: TextStyle(color: Colors.grey))));
        }

        Map<int, List<Map<String, dynamic>>> seasons = {};
        for (var ep in episodes) {
          final s = ep['season'] as int? ?? 0;
          if (!seasons.containsKey(s)) seasons[s] = [];
          seasons[s]!.add(ep);
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('حلقات ${series['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: seasons.entries.map((entry) {
                    final seasonNum = entry.key;
                    final seasonEpisodes = entry.value;
                    return ExpansionTile(
                      title: Text('الموسم $seasonNum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      children: seasonEpisodes.map((ep) {
                        final epTitle = ep['title'] ?? 'حلقة ${ep['episode']}';
                        final videoId = ep['id'] ?? '';

                        return ListTile(
                          leading: const Icon(Icons.play_circle_outline, color: Color(0xFFFF5238)),
                          title: Text(epTitle, style: const TextStyle(color: Colors.white70)),
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF1F2937),
                              isScrollControlled: true,
                              builder: (context) => _buildStreamsSheet(addonUrl, series, 'series', videoId: videoId),
                            );
                          },
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStreams(String addonUrl, String type, String videoId) async {
    final streamUrl = '$addonUrl/stream/$type/$videoId.json';
    final response = await http.get(Uri.parse(streamUrl));

    if (response.statusCode != 200) {
      throw Exception('فشل جلب الروابط (HTTP ${response.statusCode})');
    }

    final jsonData = json.decode(response.body);
    final streams = jsonData['streams'] as List? ?? [];

    return streams.map<Map<String, dynamic>>((s) => {
      'title': s['title'] ?? s['name'] ?? 'رابط',
      'url': s['url'] ?? '',
    }).toList();
  }

  Widget _buildStreamsSheet(String addonUrl, Map<String, dynamic> item, String type, {String? videoId}) {
    final idToUse = videoId ?? item['id'];

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchStreams(addonUrl, type, idToUse),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))));
        }
        if (snapshot.hasError) {
          return SizedBox(height: 200, child: Center(child: Text('فشل: ${snapshot.error}', style: const TextStyle(color: Colors.red))));
        }

        final streams = snapshot.data ?? [];
        if (streams.isEmpty) {
          return const SizedBox(height: 200, child: Center(child: Text('لا توجد روابط متاحة', style: TextStyle(color: Colors.grey))));
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('روابط البث لـ ${item['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: streams.length,
                  itemBuilder: (context, index) {
                    final stream = streams[index];
                    final title = stream['title'] ?? 'رابط ${index + 1}';
                    final url = stream['url'] ?? '';
                    final isTorrent = url.startsWith('magnet:');

                    return ListTile(
                      leading: Icon(isTorrent ? Icons.cloud_download : Icons.play_circle, color: const Color(0xFFFF5238)),
                      title: Text(title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(isTorrent ? 'تورنت (P2P)' : 'رابط مباشر', style: const TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              streamUrl: url,
                              channelName: item['name'],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // للبحث
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    final List<Map<String, dynamic>> results = [];
    _catalogContents.forEach((key, items) {
      for (var item in items) {
        if ((item['name'] as String).toLowerCase().contains(lowerQuery)) {
          results.add(item);
        }
      }
    });
    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))));
    }

    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))));
    }

    List<Map<String, dynamic>> bannerItems = [];
    _catalogContents.forEach((key, list) => bannerItems.addAll(list));
    final featuredItems = bannerItems.take(6).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: const Color(0xFF0B0E14),
              pinned: true,
              expandedHeight: MediaQuery.of(context).size.height * 0.5,
              floating: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFFF5238)),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                    });
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildBanner(featuredItems),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Column(
                  children: [
                    if (_isSearching)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن فيلم أو مسلسل...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5238)),
                            filled: true,
                            fillColor: const Color(0xFF1F2937),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFFFF5238),
                      labelColor: const Color(0xFFFF5238),
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: 'الرئيسية'),
                        Tab(text: 'الأفلام'),
                        Tab(text: 'المسلسلات'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _isSearching && _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildHomeTab(),
            _buildMediaGrid(_allMovies, 'movie'),
            _buildMediaGrid(_allSeries, 'series'),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey)));
    }
    return _buildMediaGrid(_searchResults, 'movie');
  }

  Widget _buildBanner(List<Map<String, dynamic>> bannerItems) {
    if (bannerItems.isEmpty) return Container(color: Colors.black);

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: bannerItems.length,
          onPageChanged: (index) {
            setState(() {
              _currentBannerIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final item = bannerItems[index];
            return GestureDetector(
              onTap: () => _playItem(item),
              child: Container(
                // الصورة تملأ البانر بالكامل
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(item['poster'] ?? ''),
                    fit: BoxFit.cover,
                    onError: (e, s) {},
                  ),
                ),
                // تدرج لوني (لدمج الصورة مع الخلفية)
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        const Color(0xFF0B0E14),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                  // النص والزر (في طبقة منفصلة)
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? 'بدون اسم',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _playItem(item),
                          icon: const Icon(Icons.play_arrow, size: 28),
                          label: const Text('تشغيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5238),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        // النقاط السفلية
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: bannerItems.asMap().entries.map((entry) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBannerIndex == entry.key
                      ? const Color(0xFFFF5238)
                      : Colors.grey.withOpacity(0.5),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      slivers: [
        ..._catalogContents.entries.map((entry) {
          return SliverToBoxAdapter(
            child: _buildHorizontalSection(entry.key, entry.value),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHorizontalSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // العنوان (بدون شعار الإضافة)
              Expanded(
                child: Text(
                  title.split(' - ').last, // إزالة اسم الإضافة من العنوان
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _SeeAllScreen(
                        title: title,
                        items: items,
                        onItemTap: _playItem,
                      ),
                    ),
                  );
                },
                child: const Text('عرض الكل', style: TextStyle(color: Color(0xFFFF5238))),
              ),
            ],
          ),
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
                          child: (item['poster'] != null && item['poster'].isNotEmpty)
                              ? Image.network(item['poster'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie))
                              : const Icon(Icons.movie),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white)),
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

  Widget _buildMediaGrid(List<Map<String, dynamic>> items, String type) {
    if (items.isEmpty) return const Center(child: Text('لا توجد عناصر', style: TextStyle(color: Colors.grey)));

    return SafeArea(
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => _playItem(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (item['poster'] != null && item['poster'].isNotEmpty)
                        ? Image.network(item['poster'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)))
                        : Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(item['name'], maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// شاشة "عرض الكل"
class _SeeAllScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onItemTap;

  const _SeeAllScreen({
    required this.title,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(title),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () => onItemTap(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: (item['poster'] != null && item['poster'].isNotEmpty)
                          ? Image.network(item['poster'], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)))
                          : Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item['name'], maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
