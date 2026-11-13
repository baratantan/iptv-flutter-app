import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'package:airo_m3u_parser/m3u_parser.dart' as airo_m3u_parser;
import '../services/data_service.dart';
import 'player_screen.dart';
import 'movie_details_screen.dart';
import 'category_screen.dart';
import 'series_details_screen.dart';
import 'settings_screen.dart';
import 'addons_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<XtLiveChannel> _allLiveChannels = []; 
  List<XtVodItem> _allMovies = [];
  List<XtSeriesItem> _allSeries = [];
  
  List<XtVodItem> _moviesForBanner = [];
  List<XtVodItem> _latestMovies = [];
  List<XtSeriesItem> _latestSeries = [];
  List<XtLiveChannel> _latestChannels = [];
  List<XtCategory> _categories = [];

  String _server = '';
  String _username = '';
  String _password = '';

  final PageController _pageController = PageController(viewportFraction: 1.0);
  int _currentPage = 0;
  Timer? _timer;
  int _currentTabIndex = 0;
  int _addonsKey = 0;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  String _channelSearchQuery = '';
  String _selectedChannelCategory = 'all';
  final TextEditingController _channelSearchController = TextEditingController();
  List<String> _favoriteChannelIds = [];
  List<XtCategory> _liveCategories = [];

  String _seriesSearchQuery = '';
  String _selectedSeriesCategory = 'all';
  final TextEditingController _seriesSearchController = TextEditingController();
  List<XtCategory> _seriesCategories = [];

  String _movieSearchQuery = '';
  String _selectedMovieCategory = 'all';
  final TextEditingController _movieSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadFavorites();
    _startAutoPlay();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorite_channels');
    if (favoritesJson != null) {
      final List<dynamic> decoded = json.decode(favoritesJson);
      setState(() {
        _favoriteChannelIds = decoded.cast<String>();
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_channels', json.encode(_favoriteChannelIds));
  }

  void _toggleFavorite(String channelId) {
    setState(() {
      if (_favoriteChannelIds.contains(channelId)) {
        _favoriteChannelIds.remove(channelId);
      } else {
        _favoriteChannelIds.add(channelId);
      }
    });
    _saveFavorites();
  }

  bool _isValidChannel(String? name) {
    if (name == null || name.isEmpty) return false;
    final trimmed = name.trim();
    if (trimmed.startsWith('#') || trimmed.endsWith('#')) return false;
    if (trimmed.startsWith('-') || trimmed.endsWith('-')) return false;
    if (trimmed.startsWith('*') || trimmed.endsWith('*')) return false;
    if (trimmed.length < 2) return false;
    return true;
  }

  String _getQuality(String? name) {
    if (name == null) return '';
    final upperName = name.toUpperCase();
    if (upperName.contains('8K')) return '8K';
    if (upperName.contains('4K')) return '4K';
    if (upperName.contains('FHD')) return 'FHD';
    if (upperName.contains('HD')) return 'HD';
    if (upperName.contains('SD')) return 'SD';
    return '';
  }

  String cleanTitle(String? title) {
    if (title == null || title.isEmpty) return 'بدون اسم';
    String cleaned = title;
    cleaned = cleaned.replaceAll(RegExp(r'^(4K-TOP\s*-\s*|VOD\s*\|\s*[A-Z]+\s*-\s*|FHD\s*-\s*|SD\s*-\s*|HD\s*-\s*|4K\s*-\s*|UHD\s*-\s*)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+(8K|4K|FHD|UHD|HD|SD)\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*[◉●○◎]\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\[?(8K|4K|FHD|UHD|HD|SD)\]?\s*$', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^[\-\|\s]+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*[◉●○◎]\s*'), ' ');
    return cleaned.trim();
  }

  Map<String, String> parseMovieTitle(String? title) {
    if (title == null || title.isEmpty) {
      return {'name': 'بدون اسم', 'year': '', 'hasSub': 'false'};
    }
    String cleaned = title;
    String year = '';
    String hasSub = 'false';
    
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z]{2,3}\s*-\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^VOD\s*\|\s*[A-Z]{2,3}\s*-\s*', caseSensitive: false), '');
    
    if (cleaned.toUpperCase().contains('MULTI-SUB')) {
      hasSub = 'true';
    }
    
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*\[?MULTI-SUB\]?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[?MULTI-SUB\]?', caseSensitive: false), '');
    
    final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(cleaned);
    if (yearMatch != null) {
      year = yearMatch.group(1) ?? '';
      cleaned = cleaned.replaceFirst(yearMatch.group(0)!, '').trim();
    }
    
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*$'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[\-\|\s]+'), '').trim();
    
    return {'name': cleaned.isEmpty ? 'بدون اسم' : cleaned, 'year': year, 'hasSub': hasSub};
  }

  String cleanSeriesTitle(String? title) {
    if (title == null || title.isEmpty) return 'بدون اسم';
    String cleaned = title;
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z]{2,3}\s*-\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*\[?MULTI-SUB\]?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[?MULTI-SUB\]?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_moviesForBanner.isNotEmpty && _pageController.hasClients) {
        if (_currentPage < _moviesForBanner.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _channelSearchController.dispose();
    _seriesSearchController.dispose();
    _movieSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sourceType = prefs.getString('source_type') ?? 'xtream';

      if (sourceType == 'm3u') {
        final m3uContent = prefs.getString('m3u_content') ?? '';
        if (m3uContent.isEmpty) throw Exception('لا يوجد محتوى M3U');

        final playlist = await airo_m3u_parser.parseM3uAsync(m3uContent);
        final entries = playlist.entries; 
        
        final List<XtLiveChannel> m3uChannels = entries
            .where((ch) => _isValidChannel(ch.name))
            .map((ch) {
              return XtLiveChannel(
                streamId: 0,
                name: ch.name,
                categoryId: '0',
                logoUrl: ch.logo,
              );
            }).toList();

        setState(() {
          _allLiveChannels = m3uChannels;
          _latestChannels = m3uChannels.take(12).toList();
          _allMovies = [];
          _allSeries = [];
          _moviesForBanner = [];
          _latestMovies = [];
          _latestSeries = [];
          _isLoading = false;
        });
        return;
      }

      _server = prefs.getString('xtream_server') ?? '';
      _username = prefs.getString('xtream_username') ?? '';
      _password = prefs.getString('xtream_password') ?? '';

      if (_server.isEmpty) throw Exception('لم يتم العثور على بيانات الاتصال');

      await DataService.loadXtreamData(
        server: _server,
        username: _username,
        password: _password,
        forceRefresh: forceRefresh,
      );

      final allLive = DataService.liveChannels ?? [];
      final allMovies = DataService.movies ?? [];
      final allSeries = DataService.series ?? [];
      final vodCategories = DataService.vodCategories ?? [];
      final liveCategories = DataService.liveCategories ?? [];
      final seriesCategories = DataService.seriesCategories ?? [];
      
      final filteredLive = allLive.where((ch) => _isValidChannel(ch.name)).toList();

      setState(() {
        _allLiveChannels = filteredLive;
        _allMovies = allMovies;
        _allSeries = allSeries;

        _moviesForBanner = allMovies.take(6).toList();
        _latestMovies = allMovies.take(12).toList();
        _latestSeries = allSeries.take(12).toList();
        _latestChannels = filteredLive.take(12).toList();
        _categories = vodCategories;
        _liveCategories = liveCategories;
        _seriesCategories = seriesCategories;
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _playStream(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(streamUrl: url, channelName: title),
      ),
    );
  }

  // دالة فتح تفاصيل الفيلم (مع streamId)
  void _openMovieDetails(String name, String url, String? poster, {String? streamId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(
          movieName: name,
          streamUrl: url,
          posterUrl: poster,
          streamId: streamId,
          server: _server,
          username: _username,
          password: _password,
        ),
      ),
    );
  }

  void _openCategory(XtCategory cat, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryScreen(
          category: cat,
          type: type,
          server: _server,
          username: _username,
          password: _password,
        ),
      ),
    );
  }

  void _openSeriesDetails(XtSeriesItem seriesItem) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeriesDetailsScreen(
          seriesItem: seriesItem,
          server: _server,
          username: _username,
          password: _password,
        ),
      ),
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    final List<dynamic> results = [];
    
    for (var item in _allMovies) {
      if ((item.name ?? '').toLowerCase().contains(lowerQuery)) {
        results.add({'type': 'movie', 'item': item});
      }
    }
    for (var item in _allSeries) {
      if ((item.name ?? '').toLowerCase().contains(lowerQuery)) {
        results.add({'type': 'series', 'item': item});
      }
    }
    for (var item in _allLiveChannels) {
      if ((item.name ?? '').toLowerCase().contains(lowerQuery)) {
        results.add({'type': 'channel', 'item': item});
      }
    }
    
    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))));
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(body: Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))));
    }

    final List<Widget> pages = [
      _buildHomeTab(),
      _buildChannelsTab(),
      _buildMoviesTab(),
      _buildSeriesTab(),
      AddonsScreen(key: ValueKey(_addonsKey)), 
      const SizedBox(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: IndexedStack(
        index: _currentTabIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111827),
        selectedItemColor: const Color(0xFFFF5238),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentTabIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 5) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) {
              setState(() {
                _addonsKey++;
              });
            });
          } else {
            setState(() {
              _currentTabIndex = index;
              if (index == 4) {
                _addonsKey++;
              }
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'القنوات'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'الأفلام'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'المسلسلات'),
          BottomNavigationBarItem(icon: Icon(Icons.extension), label: 'الإضافات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF0B0E14),
          pinned: true,
          expandedHeight: MediaQuery.of(context).size.height * 0.5,
          floating: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search, color: const Color(0xFFFF5238)),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchResults = [];
                  }
                });
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildCinematicBanner(),
          ),
        ),
        
        if (_isSearching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث في الأفلام والمسلسلات والقنوات...',
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
          ),

        if (!_isSearching)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ActionChip(
                      label: Text(cat.name ?? ''),
                      backgroundColor: const Color(0xFF1F2937),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () => _openCategory(cat, 'movie'),
                    ),
                  );
                },
              ),
            ),
          ),

        if (_isSearching && _searchController.text.isNotEmpty)
          SliverToBoxAdapter(child: _buildSearchResults())
        else ...[
          SliverToBoxAdapter(child: _buildHorizontalSection('أحدث الأفلام', _latestMovies, 'movie')),
          SliverToBoxAdapter(child: _buildHorizontalSection('أحدث المسلسلات', _latestSeries, 'series')),
          SliverToBoxAdapter(child: _buildHorizontalSection('أحدث القنوات', _latestChannels, 'channel')),
          
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ],
    );
  }

  Widget _buildCinematicBanner() {
    if (_moviesForBanner.isEmpty) return Container(color: Colors.black);

    return PageView.builder(
      controller: _pageController,
      itemCount: _moviesForBanner.length,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemBuilder: (context, index) {
        final movie = _moviesForBanner[index];
        final url = '$_server/movie/$_username/$_password/${movie.streamId}.mp4';
        final parsedTitle = parseMovieTitle(movie.name);
        final displayName = parsedTitle['name'] ?? 'بدون اسم';
        
        return GestureDetector(
          onTap: () => _openMovieDetails(
            displayName, url, movie.posterUrl, 
            streamId: movie.streamId.toString(),
          ),
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(movie.posterUrl ?? ''),
                fit: BoxFit.cover,
                onError: (e, s) {},
              ),
            ),
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
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
                      onPressed: () => _openMovieDetails(
                        displayName, url, movie.posterUrl, 
                        streamId: movie.streamId.toString(),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('تشغيل الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5238),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _moviesForBanner.asMap().entries.map((entry) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == entry.key
                                ? const Color(0xFFFF5238)
                                : Colors.grey.withOpacity(0.5),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey))));
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final type = result['type'];
        final item = result['item'];
        
        String poster = '';
        String name = '';
        if (type == 'movie') {
          poster = item.posterUrl ?? '';
          name = parseMovieTitle(item.name)['name'] ?? '';
        } else if (type == 'series') {
          poster = item.posterUrl ?? '';
          name = cleanSeriesTitle(item.name);
        } else if (type == 'channel') {
          poster = item.logoUrl ?? '';
          name = cleanTitle(item.name);
        }
        
        return GestureDetector(
          onTap: () {
            if (type == 'movie') {
              final url = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
              _openMovieDetails(name, url, poster, streamId: item.streamId.toString());
            } else if (type == 'series') {
              _openSeriesDetails(item);
            } else if (type == 'channel') {
              final url = '$_server/live/$_username/$_password/${item.streamId}.m3u8';
              _playStream(url, name);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: poster.isNotEmpty
                      ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie))
                      : const Icon(Icons.movie),
                ),
              ),
              const SizedBox(height: 4),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalSection(String title, List<dynamic> items, String type) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _SeeAllScreen(
                        title: title,
                        items: items,
                        type: type,
                        server: _server,
                        username: _username,
                        password: _password,
                        onItemTap: (item) {
                          if (type == 'movie') {
                            final url = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
                            _openMovieDetails(
                              parseMovieTitle(item.name)['name'] ?? '', 
                              url, 
                              item.posterUrl, 
                              streamId: item.streamId.toString(),
                            );
                          } else if (type == 'channel') {
                            final url = '$_server/live/$_username/$_password/${item.streamId}.m3u8';
                            _playStream(url, cleanTitle(item.name));
                          } else {
                            _openSeriesDetails(item);
                          }
                        },
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
              final name = type == 'movie' ? (parseMovieTitle(item.name)['name'] ?? '') : cleanTitle(item.name);
              String poster = '';
              if (type == 'movie') {
                poster = item.posterUrl ?? '';
              } else if (type == 'series') {
                poster = item.posterUrl ?? '';
              } else if (type == 'channel') {
                poster = item.logoUrl ?? '';
              }
              return GestureDetector(
                onTap: () {
                  if (type == 'movie') {
                    final url = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
                    _openMovieDetails(name, url, poster, streamId: item.streamId.toString());
                  } else if (type == 'channel') {
                    final url = '$_server/live/$_username/$_password/${item.streamId}.m3u8';
                    _playStream(url, name);
                  } else {
                    _openSeriesDetails(item);
                  }
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: poster.isNotEmpty
                              ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie))
                              : const Icon(Icons.movie),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            name,
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

  Widget _buildChannelsTab() {
    final validCategories = _liveCategories.where((cat) {
      final catId = cat.id ?? '';
      return _allLiveChannels.any((ch) => (ch.categoryId ?? '') == catId);
    }).toList();

    List<XtLiveChannel> filteredChannels = _allLiveChannels.where((ch) {
      final matchesSearch = _channelSearchQuery.isEmpty ||
          (ch.name ?? '').toLowerCase().contains(_channelSearchQuery.toLowerCase());
      final matchesCategory = _selectedChannelCategory == 'all' ||
          (ch.categoryId ?? '') == _selectedChannelCategory ||
          (_selectedChannelCategory == 'favorites' && _favoriteChannelIds.contains(ch.streamId.toString()));
      return matchesSearch && matchesCategory;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _channelSearchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن قناة...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5238)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _channelSearchQuery = value;
                });
              },
            ),
          ),
          
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildChannelCategoryChip('all', 'الكل'),
                _buildChannelCategoryChip('favorites', '⭐ المفضلة'),
                ...validCategories.map((cat) {
                  return _buildChannelCategoryChip(cat.id ?? '', cat.name ?? '');
                }).toList(),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: filteredChannels.isEmpty
                ? const Center(child: Text('لا توجد قنوات', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: filteredChannels.length,
                    itemBuilder: (context, index) {
                      final channel = filteredChannels[index];
                      final quality = _getQuality(channel.name);
                      final isFavorite = _favoriteChannelIds.contains(channel.streamId.toString());
                      
                      return ListTile(
                        onTap: () {
                          final streamUrl = '$_server/live/$_username/$_password/${channel.streamId}.m3u8';
                          _playStream(streamUrl, cleanTitle(channel.name));
                        },
                        leading: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                            ? Image.network(channel.logoUrl!, width: 50, height: 50, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                            : const Icon(Icons.tv),
                        title: Text(cleanTitle(channel.name)),
                        subtitle: quality.isNotEmpty
                            ? Wrap(
                                alignment: WrapAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5238).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      quality,
                                      style: const TextStyle(color: Color(0xFFFF5238), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                        trailing: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(channel.streamId.toString()),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCategoryChip(String id, String name) {
    final isSelected = _selectedChannelCategory == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedChannelCategory = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5238) : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoviesTab() {
    List<XtVodItem> filteredMovies = _allMovies.where((m) {
      final matchesSearch = _movieSearchQuery.isEmpty ||
          (m.name ?? '').toLowerCase().contains(_movieSearchQuery.toLowerCase());
      final matchesCategory = _selectedMovieCategory == 'all' ||
          (m.categoryId ?? '') == _selectedMovieCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _movieSearchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن فيلم...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5238)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _movieSearchQuery = value;
                });
              },
            ),
          ),
          
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMovieCategoryChip('all', 'الكل'),
                ..._categories.map((cat) {
                  return _buildMovieCategoryChip(cat.id ?? '', cat.name ?? '');
                }).toList(),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: filteredMovies.isEmpty
                ? const Center(child: Text('لا توجد أفلام', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredMovies.length,
                    itemBuilder: (context, index) {
                      final item = filteredMovies[index];
                      final parsed = parseMovieTitle(item.name);
                      final displayName = parsed['name'] ?? 'بدون اسم';
                      final year = parsed['year'] ?? '';
                      final hasSub = parsed['hasSub'] == 'true';
                      final poster = item.posterUrl ?? '';
                      
                      return GestureDetector(
                        onTap: () {
                          final url = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
                          _openMovieDetails(displayName, url, poster, streamId: item.streamId.toString());
                        },
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: poster.isNotEmpty
                                        ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)))
                                        : Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                            if (hasSub)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SUB',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            if (year.isNotEmpty)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    year,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCategoryChip(String id, String name) {
    final isSelected = _selectedMovieCategory == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMovieCategory = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5238) : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeriesTab() {
    List<XtSeriesItem> filteredSeries = _allSeries.where((s) {
      final matchesSearch = _seriesSearchQuery.isEmpty ||
          (s.name ?? '').toLowerCase().contains(_seriesSearchQuery.toLowerCase());
      final matchesCategory = _selectedSeriesCategory == 'all' ||
          (s.categoryId ?? '') == _selectedSeriesCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _seriesSearchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن مسلسل...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5238)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _seriesSearchQuery = value;
                });
              },
            ),
          ),
          
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSeriesCategoryChip('all', 'الكل'),
                ..._seriesCategories.map((cat) {
                  return _buildSeriesCategoryChip(cat.id ?? '', cat.name ?? '');
                }).toList(),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: filteredSeries.isEmpty
                ? const Center(child: Text('لا توجد مسلسلات', style: TextStyle(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredSeries.length,
                    itemBuilder: (context, index) {
                      final item = filteredSeries[index];
                      final originalName = item.name ?? '';
                      final cleanedName = cleanSeriesTitle(originalName);
                      final hasSub = originalName.toUpperCase().contains('MULTI-SUB');
                      final poster = item.posterUrl ?? '';
                      
                      return GestureDetector(
                        onTap: () => _openSeriesDetails(item),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: poster.isNotEmpty
                                        ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.video_library, color: Colors.grey)))
                                        : Container(color: Colors.grey[900], child: const Icon(Icons.video_library, color: Colors.grey)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(cleanedName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                            if (hasSub)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SUB',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesCategoryChip(String id, String name) {
    final isSelected = _selectedSeriesCategory == id;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSeriesCategory = id;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF5238) : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeeAllScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final String type;
  final String server;
  final String username;
  final String password;
  final Function(dynamic) onItemTap;

  const _SeeAllScreen({
    required this.title,
    required this.items,
    required this.type,
    required this.server,
    required this.username,
    required this.password,
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
            final name = type == 'movie' ? (item.name ?? '') : cleanTitle(item.name);
            String poster = '';
            if (type == 'movie') {
              poster = item.posterUrl ?? '';
            } else if (type == 'series') {
              poster = item.posterUrl ?? '';
            } else if (type == 'channel') {
              poster = item.logoUrl ?? '';
            }
            return GestureDetector(
              onTap: () => onItemTap(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: poster.isNotEmpty
                          ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)))
                          : Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String cleanTitle(String? title) {
  if (title == null || title.isEmpty) return 'بدون اسم';
  String cleaned = title;
  cleaned = cleaned.replaceAll(RegExp(r'^(4K-TOP\s*-\s*|VOD\s*\|\s*[A-Z]+\s*-\s*|FHD\s*-\s*|SD\s*-\s*|HD\s*-\s*|4K\s*-\s*|UHD\s*-\s*)', caseSensitive: false), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s+(8K|4K|FHD|UHD|HD|SD)\s*$', caseSensitive: false), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s*[◉●○◎]\s*$'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s*\[?(8K|4K|FHD|UHD|HD|SD)\]?\s*$', caseSensitive: false), '');
  cleaned = cleaned.replaceAll(RegExp(r'^[\-\|\s]+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'\s*[◉●○◎]\s*'), ' ');
  return cleaned.trim();
}
