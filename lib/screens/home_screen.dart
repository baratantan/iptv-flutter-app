import 'dart:async';
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

  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;
  int _currentTabIndex = 0;
  int _addonsKey = 0;

  // للبحث
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoPlay();
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
        
        final List<XtLiveChannel> m3uChannels = entries.map((ch) {
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

      setState(() {
        _allLiveChannels = allLive;
        _allMovies = allMovies;
        _allSeries = allSeries;

        _moviesForBanner = allMovies.take(6).toList();
        _latestMovies = allMovies.take(12).toList();
        _latestSeries = allSeries.take(12).toList();
        _latestChannels = allLive.take(12).toList();
        _categories = vodCategories;
        
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

  void _openMovieDetails(String name, String url, String? poster) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailsScreen(
          movieName: name,
          streamUrl: url,
          posterUrl: poster,
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
    
    // بحث في الأفلام
    for (var item in _allMovies) {
      if ((item.name ?? '').toLowerCase().contains(lowerQuery)) {
        results.add({'type': 'movie', 'item': item});
      }
    }
    // بحث في المسلسلات
    for (var item in _allSeries) {
      if ((item.name ?? '').toLowerCase().contains(lowerQuery)) {
        results.add({'type': 'series', 'item': item});
      }
    }
    // بحث في القنوات
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
      _buildMediaGrid(_allMovies, 'movie'), 
      _buildMediaGrid(_allSeries, 'series'), 
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
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(top: 20),
          children: [
            // شريط البحث (يظهر عند الضغط على أيقونة البحث)
            if (_isSearching)
              Padding(
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
            
            // البانر
            if (_moviesForBanner.isNotEmpty)
              SizedBox(
                height: 320,
                child: PageView.builder(
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
                    return GestureDetector(
                      onTap: () => _openMovieDetails(movie.name ?? 'فيلم', url, movie.posterUrl),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(movie.posterUrl ?? ''),
                            fit: BoxFit.cover,
                            onError: (exception, stackTrace) {},
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
                                  movie.name ?? 'بدون اسم',
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _openMovieDetails(movie.name ?? 'فيلم', url, movie.posterUrl),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('تشغيل الآن'),
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
            
            const SizedBox(height: 16),
            
            // أزرار التصنيفات
            SizedBox(
              height: 40,
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
            
            const SizedBox(height: 16),
            
            // البحث (النتائج) أو الشرائط
            if (_isSearching && _searchController.text.isNotEmpty)
              _buildSearchResults()
            else ...[
              _buildHorizontalSection('أحدث الأفلام', _latestMovies, 'movie'),
              _buildHorizontalSection('أحدث المسلسلات', _latestSeries, 'series'),
              _buildHorizontalSection('أحدث القنوات', _latestChannels, 'channel'),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
        // زر البحث (العائم)
        Positioned(
          top: 10,
          right: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey)));
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
          name = item.name ?? '';
        } else if (type == 'series') {
          poster = item.posterUrl ?? '';
          name = item.name ?? '';
        } else if (type == 'channel') {
          poster = item.logoUrl ?? '';
          name = item.name ?? '';
        }
        
        return GestureDetector(
          onTap: () {
            if (type == 'movie') {
              final url = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
              _openMovieDetails(name, url, poster);
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
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                            _openMovieDetails(item.name ?? 'فيلم', url, item.posterUrl);
                          } else if (type == 'channel') {
                            final url = '$_server/live/$_username/$_password/${item.streamId}.m3u8';
                            _playStream(url, item.name ?? 'قناة');
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
              final name = item.name ?? 'بدون اسم';
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
                    _openMovieDetails(name, url, poster);
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
                            style: const TextStyle(fontSize: 11),
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
    return SafeArea(
      child: ListView.builder(
        itemCount: _allLiveChannels.length,
        itemBuilder: (context, index) {
          final channel = _allLiveChannels[index];
          final streamUrl = '$_server/live/$_username/$_password/${channel.streamId}.m3u8';
          return ListTile(
            onTap: () => _playStream(streamUrl, channel.name ?? 'قناة'),
            leading: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                ? Image.network(channel.logoUrl!, width: 50, height: 50, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                : const Icon(Icons.tv),
            title: Text(channel.name ?? 'بدون اسم'),
            subtitle: Text('ID: ${channel.streamId}'),
          );
        },
      ),
    );
  }

  Widget _buildMediaGrid(List<dynamic> items, String type) {
    if (items.isEmpty) return const Center(child: Text('لا توجد عناصر'));

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
          final name = item.name ?? 'بدون اسم';
          final poster = type == 'movie' ? (item.posterUrl ?? '') : (item.posterUrl ?? '');

          return GestureDetector(
            onTap: () {
              if (type == 'movie') {
                final streamUrl = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
                _openMovieDetails(name, streamUrl, poster);
              } else {
                _openSeriesDetails(item);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: poster.isNotEmpty
                        ? Image.network(
                            poster,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.movie, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// شاشة "عرض الكل" للصفحة الرئيسية
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
            final name = item.name ?? 'بدون اسم';
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
