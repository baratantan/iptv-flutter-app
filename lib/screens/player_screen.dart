import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:local_pip/local_pip.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String channelName;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.channelName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player;
  late final VideoController controller;
  final LocalPip _localPip = LocalPip();
  bool _isPipAvailable = false;

  bool _isLoading = true;
  bool _isBuffering = true;
  String? _errorMessage;
  int? _torrentId;
  StreamSubscription? _torrentSubscription;
  StreamSubscription? _bufferingSubscription;
  StreamSubscription? _subtitleTracksSubscription;
  StreamSubscription? _currentSubtitleSubscription;

  BoxFit _currentFit = BoxFit.contain;
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _currentSubtitleTrack;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _checkPipAvailability();

    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _subtitleTracksSubscription = player.stream.tracks.subtitle.listen((tracks) {
      if (mounted) setState(() => _subtitleTracks = tracks);
    });

    _currentSubtitleSubscription = player.stream.track.subtitle.listen((track) {
      if (mounted) setState(() => _currentSubtitleTrack = track);
    });

    _initializeStream();
  }

  Future<void> _checkPipAvailability() async {
    try {
      final available = await _localPip.isPipAvailable();
      if (mounted) setState(() => _isPipAvailable = available);
    } catch (e) {
      debugPrint('PiP check failed: $e');
    }
  }

  Future<void> _enterPipMode() async {
    try {
      await _localPip.enterPipMode();
    } catch (e) {
      debugPrint('Failed to enter PiP: $e');
    }
  }

  Future<void> _initializeStream() async {
    try {
      if (widget.streamUrl.startsWith('magnet:')) {
        await _initTorrentStream(widget.streamUrl);
      } else {
        await _playMedia(widget.streamUrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initTorrentStream(String magnetUrl) async {
    try {
      // محاولة تهيئة محرك التورنت (إذا لم يتم تهيئته مسبقاً)
      await LibtorrentFlutter.init();
    } catch (e) {
      // إذا فشلت التهيئة، نطبع الخطأ ونكمل
      debugPrint('Torrent init failed: $e');
    }

    final id = LibtorrentFlutter.instance.addMagnet(magnetUrl);
    _torrentId = id;
    final completer = Completer<void>();

    _torrentSubscription = LibtorrentFlutter.instance.torrentUpdates.listen((torrents) {
      final t = torrents[id];
      if (t == null) return;
      if (t.hasMetadata && !completer.isCompleted) completer.complete();
    });

    await completer.future;
    final stream = LibtorrentFlutter.instance.startStream(id, maxCacheBytes: 500 * 1024 * 1024);
    await Future.delayed(const Duration(seconds: 1));
    await _playMedia(stream.url);
  }

  Future<void> _playMedia(String url) async {
    await player.open(Media(url));
    if (mounted) setState(() => _isLoading = false);
  }

  void _showFitOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('نسبة العرض', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildFitOption('ملاءمة (Fit)', BoxFit.contain, Icons.fit_screen),
            _buildFitOption('ملء (Fill)', BoxFit.cover, Icons.fullscreen),
            _buildFitOption('تمديد (Fill)', BoxFit.fill, Icons.aspect_ratio),
          ],
        ),
      ),
    );
  }

  Widget _buildFitOption(String title, BoxFit fit, IconData icon) {
    final isSelected = _currentFit == fit;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFFF5238) : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? const Color(0xFFFF5238) : Colors.white)),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFFF5238)) : null,
      onTap: () {
        setState(() => _currentFit = fit);
        Navigator.pop(context);
      },
    );
  }

  void _showSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('الترجمة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(
                _currentSubtitleTrack == null ? Icons.check : Icons.subtitles_off,
                color: _currentSubtitleTrack == null ? const Color(0xFFFF5238) : Colors.grey,
              ),
              title: Text('إيقاف', style: TextStyle(color: _currentSubtitleTrack == null ? const Color(0xFFFF5238) : Colors.white)),
              onTap: () {
                player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(context);
              },
            ),
            ..._subtitleTracks.map((track) {
              final isSelected = _currentSubtitleTrack == track;
              return ListTile(
                leading: Icon(isSelected ? Icons.check : Icons.subtitles, color: isSelected ? const Color(0xFFFF5238) : Colors.grey),
                title: Text(track.title ?? track.language ?? 'ترجمة غير معروفة', style: TextStyle(color: isSelected ? const Color(0xFFFF5238) : Colors.white)),
                onTap: () {
                  player.setSubtitleTrack(track);
                  Navigator.pop(context);
                },
              );
            }).toList(),
            if (_subtitleTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('لا توجد ترجمات متاحة لهذا الفيديو', style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bufferingSubscription?.cancel();
    _torrentSubscription?.cancel();
    _subtitleTracksSubscription?.cancel();
    _currentSubtitleSubscription?.cancel();
    if (_torrentId != null) {
      LibtorrentFlutter.instance.removeTorrent(_torrentId!, deleteFiles: true);
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.channelName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.subtitles, color: Color(0xFFFF5238)),
            onPressed: _showSubtitleOptions,
            tooltip: 'الترجمة',
          ),
          IconButton(
            icon: const Icon(Icons.aspect_ratio, color: Color(0xFFFF5238)),
            onPressed: _showFitOptions,
            tooltip: 'نسبة العرض',
          ),
          if (_isPipAvailable)
            IconButton(
              icon: const Icon(Icons.picture_in_picture_alt, color: Color(0xFFFF5238)),
              onPressed: _enterPipMode,
              tooltip: 'صورة داخل صورة',
            ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Video(
              controller: controller,
              controls: AdaptiveVideoControls,
              fit: _currentFit,
            ),
          ),
          if (_isLoading || _isBuffering)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238))),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}
