
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'player_screen.dart';
import 'movie_details_screen.dart';
import 'category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<XtVodItem> _moviesForBanner = [];
  List<XtVodItem> _latestMovies = [];
  List<XtSeriesItem> _latestSeries = [];
  List<XtLiveChannel> _latestChannels = [];
  List<XtCategory> _categories = [];

  List<XtLiveChannel> _allLiveChannels = []; 
  List<XtCategory> _vodCategories = [];
  List<XtCategory> _seriesCategories = [];

  String _server = '';
  String _username = '';
  String _password = '';
  
  int _currentBannerIndex = 0;
  // التصحيح: نستخدم اسم الحزمة للتفريق بينها وبين CarouselController الخاص بـ Flutter
  final carousel_slider.CarouselController _carouselController = carousel_slider.CarouselController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
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
        _moviesForBanner = allMovies.take(6).toList();
        _latestMovies = allMovies.take(12).toList();
        _latestSeries = allSeries.take(12).toList();
        _latestChannels = allLive.take(12).toList();
        _categories = (results[3] as List).cast<XtCategory>(); 

        _allLiveChannels = allLive;
        _vodCategories = (results[3] as List).cast<XtCategory>();
        _seriesCategories = (results[4] as List).cast<XtCategory>();
        
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: const Text('المكتبة'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFFFF5238),
            labelColor: Color(0xFFFF5238),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'الرئيسية', icon: Icon(Icons.home)),
              Tab(text: 'القنوات', icon: Icon(Icons.live_tv)),
              Tab(text: 'الأفلام', icon: Icon(Icons.movie)),
              Tab(text: 'المسلسلات', icon: Icon(Icons.video_library)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHomeTab(),
            _buildChannelsTab(),
            _buildCategoriesTab(_vodCategories, 'movie'),
            _buildCategoriesTab(_seriesCategories, 'series'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return ListView(
      children: [
        Column(
          children: [
            CarouselSlider(
              carouselController: _carouselController,
              options: CarouselOptions(
                height: 250.0,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 5),
                enlargeCenterPage: true,
                viewportFraction: 0.9,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentBannerIndex = index;
                  });
                },
              ),
              items: _moviesForBanner.map((movie) {
                final url = '$_server/movie/$_username/$_password/${movie.streamId}.mp4';
                return Builder(
                  builder: (BuildContext context) {
                    return GestureDetector(
                      onTap: () => _openMovieDetails(movie.name ?? 'فيلم', url, movie.posterUrl),
                      child: Container(
                        width: MediaQuery.of(context).size.width,
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
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            SmoothPageIndicator(
              controller: _carouselController,
              count: _moviesForBanner.length,
              effect: const ExpandingDotsEffect(
                activeDotColor: Color(0xFFFF5238),
                dotColor: Colors.grey,
                dotHeight: 8,
                dotWidth: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('المسلسلات قادمة قريباً')),
                    );
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
    return ListView.builder(
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
    );
  }

  Widget _buildCategoriesTab(List<XtCategory> categories, String type) {
    if (categories.isEmpty) return const Center(child: Text('لا توجد تصنيفات'));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () => _openCategory(cat, type),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Center(
              child: Text(
                cat.name ?? 'بدون اسم',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
