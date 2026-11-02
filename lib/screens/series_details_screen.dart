import 'package:flutter/material.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'player_screen.dart';

class SeriesDetailsScreen extends StatefulWidget {
  final XtSeriesItem seriesItem;
  final String server;
  final String username;
  final String password;

  const SeriesDetailsScreen({
    super.key,
    required this.seriesItem,
    required this.server,
    required this.username,
    required this.password,
  });

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  XtSeriesDetails? _seriesInfo;
  List<int> _seasonKeys = []; // تغيير النوع إلى int
  int? _selectedSeason;
  List<dynamic> _currentEpisodes = [];

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    try {
      final portal = XtreamPortal.parse(widget.server);
      final credentials = XtreamCredentials(username: widget.username, password: widget.password);
      final client = XtreamClient(portal, credentials);

      final info = await client.getSeriesInfo(widget.seriesItem.seriesId);
      
      setState(() {
        _seriesInfo = info;
        if (info != null && info.seasons != null && info.seasons!.isNotEmpty) {
          _seasonKeys = info.seasons!.keys.toList(); // الآن هي List<int>
          _selectedSeason = _seasonKeys.first;
          _currentEpisodes = info.seasons![_selectedSeason] ?? [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSeasonChanged(int? season) {
    if (season == null) return;
    setState(() {
      _selectedSeason = season;
      _currentEpisodes = _seriesInfo?.seasons?[season] ?? [];
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

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: CustomScrollView(
        slivers: [
          // 1. صورة الغلاف (Backdrop)
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF111827),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // التصحيح: استخدام posterUrl بدلاً من cover
                  _seriesInfo?.posterUrl != null && _seriesInfo!.posterUrl!.isNotEmpty
                      ? Image.network(
                          _seriesInfo!.posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
                        )
                      : Container(color: Colors.grey[900]),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0B0E14).withOpacity(0.9),
                          const Color(0xFF0B0E14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. معلومات المسلسل
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.seriesItem.name ?? 'المسلسل',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // التصحيح: تحويل rating من double إلى String
                      if (_seriesInfo?.rating != null) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _seriesInfo!.rating!.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (_seriesInfo?.releaseDate != null) ...[
                        Text(
                          _seriesInfo!.releaseDate!.substring(0, 4),
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // قائمة المواسم المنسدلة
                  if (_seasonKeys.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedSeason,
                          dropdownColor: const Color(0xFF1F2937),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF5238)),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          items: _seasonKeys.map((season) {
                            return DropdownMenuItem<int>(
                              value: season,
                              child: Text('الموسم $season'),
                            );
                          }).toList(),
                          onChanged: _onSeasonChanged,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. قائمة الحلقات
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final episode = _currentEpisodes[index];
                final epNum = episode.episode ?? '?';
                final epTitle = episode.title ?? 'حلقة $epNum';
                final epId = episode.id;
                final streamUrl = '${widget.server}/series/${widget.username}/${widget.password}/$epId.mp4';

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow, color: Color(0xFFFF5238)),
                  ),
                  title: Text(
                    'حلقة $epNum: $epTitle',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: episode.duration != null
                      ? Text('${episode.duration}', style: const TextStyle(color: Colors.grey, fontSize: 12))
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          streamUrl: streamUrl,
                          channelName: '${widget.seriesItem.name} - S$_selectedSeason E$epNum',
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: _currentEpisodes.length,
            ),
          ),
        ],
      ),
    );
  }
}
