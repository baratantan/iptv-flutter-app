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
  List<dynamic> _seasons = [];

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

      // جلب معلومات المسلسل (المواسم والحلقات)
      final info = await client.getSeriesInfo(widget.seriesItem.seriesId);
      
      setState(() {
        // في بعض السيرفرات، تأتي الحلقات داخل خريطة (Map) وليس قائمة مباشرة
        if (info != null && info.episodes != null) {
          _seasons = info.episodes!.entries.map((entry) {
            final seasonNum = entry.key;
            final episodesList = entry.value;
            return {
              'seasonNumber': seasonNum,
              'episodes': episodesList,
            };
          }).toList();
        } else {
          _seasons = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(widget.seriesItem.name ?? 'المسلسل'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238)))
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _seasons.isEmpty
                  ? const Center(child: Text('لا توجد حلقات متاحة', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _seasons.length,
                      itemBuilder: (context, index) {
                        final season = _seasons[index];
                        final seasonNumber = season['seasonNumber'];
                        final episodesList = season['episodes'] as List;

                        return ExpansionTile(
                          title: Text(
                            'الموسم $seasonNumber',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          children: episodesList.map<Widget>((episode) {
                            // التكيف مع أسماء الحقول المختلفة التي قد تأتي من السيرفر
                            final epNum = episode.episodeNum ?? episode.episodeNumber ?? '?';
                            final epTitle = episode.title ?? 'حلقة $epNum';
                            
                            // بناء رابط الحلقة بناءً على معرّف الحلقة (id أو streamId)
                            final epId = episode.id ?? episode.streamId;
                            final extension = episode.containerExtension ?? 'mp4';
                            final streamUrl = '${widget.server}/series/${widget.username}/${widget.password}/$epId.$extension';
                            
                            return ListTile(
                              leading: const Icon(Icons.play_circle_outline, color: Color(0xFFFF5238)),
                              title: Text(
                                'حلقة $epNum: $epTitle',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      streamUrl: streamUrl,
                                      channelName: '${widget.seriesItem.name} - S$seasonNumber E$epNum',
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
    );
  }
}
