import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'player_screen.dart';
import 'movie_details_screen.dart';
import 'category_screen.dart';
import 'setup_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAllData();
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
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _server = prefs.getString('xtream_server') ?? '';
      _username = prefs.getString('xtream_username') ?? '';
      _password = prefs.getString('xtream_password') ?? '';

      if (_server.isEmpty) {
        throw Exception('لم يتم العثور على بيانات الاتصال');
      }

      final portal = XtreamPortal.parse(_server);
      final credentials = XtreamCredentials(username: _username, password: _password);
      final client = XtreamClient(portal, credentials);

      final results = await Future.wait([
        client.getLiveStreams(),
        client.getVodStreams(),
        client.getSeries(),
        client.getVodCategories(),
        client.getSeriesCategories(),
      ]);

      final allLive = (results[0] as List).cast<XtLiveChannel>();
      final allMovies = (results[1] as List).cast<XtVodItem>();
      final allSeries = (results[2] as List).cast<XtSeriesItem>();

      setState(() {
        _allLiveChannels = allLive;
        _allMovies = allMovies;
        _allSeries = allSeries;

        _moviesForBanner = allMovies.take(6).toList();
        _latestMovies = allMovies.take(12).toList();
        _latestSeries = allSeries.take(12).toList();
        _latestChannels = allLive.take(12).toList();
        _categories = (results[3] as List).cast<XtCategory>(); 
        
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
        onTap: (index) {
          if (index == 4) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            );
          } else {
            setState(() {
              _currentTabIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'القنوات'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'الأفلام'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'المسلسلات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(top: 40),
          children: [
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
            
            _buildHorizontalSection('أحدث الأفلام', _latestMovies, 'movie'),
            _buildHorizontalSection('أحدث المسلسلات', _latestSeries, 'series'),
            _buildHorizontalSection('أحدث القنوات', _latestChannels, 'channel'),
            
            const SizedBox(height: 20),
          ],
        ),
        Positioned(
          top: 50,
          right: 16,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('البحث قادم قريباً')),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalSection(String title, List<dynamic> items, String type) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              String streamUrl = '';
              if (type == 'movie') {
                poster = item.posterUrl ?? '';
                streamUrl = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
              } else if (type == 'series') {
                poster = item.posterUrl ?? '';
              } else if (type == 'channel') {
                poster = item.logoUrl ?? '';
                streamUrl = '$_server/live/$_username/$_password/${item.streamId}.m3u8';
              }
              return GestureDetector(
                onTap: () {
                  if (type == 'movie') {
                    _openMovieDetails(name, streamUrl, poster);
                  } else if (type == 'channel') {
                    _playStream(streamUrl, name);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المسلسلات قادمة قريباً')));
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
          final poster = item.posterUrl ?? '';

          return GestureDetector(
            onTap: () {
              if (type == 'movie') {
                final streamUrl = '$_server/movie/$_username/$_password/${item.streamId}.mp4';
                _openMovieDetails(name, streamUrl, poster);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('قريباً: عرض حلقات المسلسل')),
                );
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
