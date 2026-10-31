import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
// import 'player_screen.dart'; // سنفعله لاحقاً

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  // قوائم لتخزين البيانات
  List<XtLiveChannel> _liveChannels = [];
  List<XtVodItem> _movies = [];
  List<XtSeriesItem> _series = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('xtream_server') ?? '';
      final username = prefs.getString('xtream_username') ?? '';
      final password = prefs.getString('xtream_password') ?? '';

      if (server.isEmpty) {
        throw Exception('لم يتم العثور على بيانات الاتصال');
      }

      final portal = XtreamPortal.parse(server);
      final credentials = XtreamCredentials(username: username, password: password);
      final client = XtreamClient(portal, credentials);

      // جلب البيانات الثلاثة معاً
      final results = await Future.wait([
        client.getLiveStreams(),
        client.getVodStreams(),
        client.getSeries(),
      ]);

      setState(() {
        _liveChannels = (results[0] as List).cast<XtLiveChannel>();
        _movies = (results[1] as List).cast<XtVodItem>();
        _series = (results[2] as List).cast<XtSeriesItem>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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

    // واجهة التبويبات (Tabs)
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: const Text('المكتبة'),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF5238),
            labelColor: Color(0xFFFF5238),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'القنوات', icon: Icon(Icons.live_tv)),
              Tab(text: 'الأفلام', icon: Icon(Icons.movie)),
              Tab(text: 'المسلسلات', icon: Icon(Icons.video_library)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildChannelsList(),
            _buildMoviesList(),
            _buildSeriesList(),
          ],
        ),
      ),
    );
  }

  // 1. واجهة القنوات المباشرة
  Widget _buildChannelsList() {
    return ListView.builder(
      itemCount: _liveChannels.length,
      itemBuilder: (context, index) {
        final channel = _liveChannels[index];
        return ListTile(
          leading: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
              ? Image.network(channel.logoUrl!, width: 50, height: 50, errorBuilder: (c, e, s) => const Icon(Icons.tv))
              : const Icon(Icons.tv),
          title: Text(channel.name ?? 'بدون اسم'),
          subtitle: Text('ID: ${channel.streamId}'),
          // onTap: () { ... تشغيل القناة ... } // سنضيفه لاحقاً
        );
      },
    );
  }

  // 2. واجهة الأفلام
  Widget _buildMoviesList() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 أعمدة
        childAspectRatio: 0.7, // نسبة الطول للعرض (للغلاف)
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        final movie = _movies[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: movie.posterUrl != null && movie.posterUrl!.isNotEmpty
                    ? Image.network(movie.posterUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie, size: 50))
                    : const Icon(Icons.movie, size: 50),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  movie.name ?? 'بدون اسم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. واجهة المسلسلات
  Widget _buildSeriesList() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _series.length,
      itemBuilder: (context, index) {
        final seriesItem = _series[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: seriesItem.coverUrl != null && seriesItem.coverUrl!.isNotEmpty
                    ? Image.network(seriesItem.coverUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.video_library, size: 50))
                    : const Icon(Icons.video_library, size: 50),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  seriesItem.name ?? 'بدون اسم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
