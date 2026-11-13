import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:local_pip/local_pip.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  double _subtitleFontSize = 16.0;
  Color _subtitleColor = Colors.white;

  // المفتاح يُقرأ من GitHub Secrets (وليس مكتوباً هنا)
  final String _openSubtitlesApiKey = const String.fromEnvironment('OPENSUBTITLES_API_KEY');

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _checkPipAvailability();
    _loadSubtitleSettings();

    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _subtitleTracksSubscription = player.stream.tracks.listen((tracks) {
      if (mounted) setState(() => _subtitleTracks = tracks.subtitle);
    });

    _currentSubtitleSubscription = player.stream.track.listen((track) {
      if (mounted) setState(() => _currentSubtitleTrack = track.subtitle);
    });

    _initializeStream();
  }

  Future<void> _loadSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _subtitleFontSize = prefs.getDouble('subtitle_font_size') ?? 16.0;
      final colorValue = prefs.getInt('subtitle_color');
      if (colorValue != null) _subtitleColor = Color(colorValue);
    });
  }

  Future<void> _saveSubtitleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('subtitle_font_size', _subtitleFontSize);
    await prefs.setInt('subtitle_color', _subtitleColor.value);
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
      await LibtorrentFlutter.init();
    } catch (e) {
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

  // ============ قائمة الترجمة ============
  void _showSubtitleOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الترجمة',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // إيقاف الترجمة
                  ListTile(
                    leading: Icon(
                      _currentSubtitleTrack == null ? Icons.check : Icons.subtitles_off,
                      color: _currentSubtitleTrack == null ? const Color(0xFFFF5238) : Colors.grey,
                    ),
                    title: Text(
                      'إيقاف',
                      style: TextStyle(color: _currentSubtitleTrack == null ? const Color(0xFFFF5238) : Colors.white),
                    ),
                    onTap: () {
                      player.setSubtitleTrack(SubtitleTrack.no());
                      Navigator.pop(context);
                    },
                  ),

                  // الترجمات المدمجة
                  ..._subtitleTracks.map((track) {
                    final isSelected = _currentSubtitleTrack == track;
                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.check : Icons.subtitles,
                        color: isSelected ? const Color(0xFFFF5238) : Colors.grey,
                      ),
                      title: Text(
                        track.title ?? track.language ?? 'ترجمة مدمجة',
                        style: TextStyle(color: isSelected ? const Color(0xFFFF5238) : Colors.white),
                      ),
                      onTap: () {
                        player.setSubtitleTrack(track);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),

                  if (_subtitleTracks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('لا توجد ترجمات مدمجة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),

                  const Divider(color: Colors.grey),

                  // جلب ترجمة عربية
                  ListTile(
                    leading: const Icon(Icons.cloud_download, color: Color(0xFFFF5238)),
                    title: const Text('جلب ترجمة عربية', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('البحث في OpenSubtitles', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _fetchArabicSubtitle();
                    },
                  ),

                  // اختيار ملف من الهاتف
                  ListTile(
                    leading: const Icon(Icons.folder_open, color: Color(0xFFFF5238)),
                    title: const Text('اختيار ملف ترجمة من الهاتف', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('ملفات .srt أو .vtt', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickSubtitleFile();
                    },
                  ),

                  const Divider(color: Colors.grey),

                  // حجم الخط
                  Row(
                    children: [
                      const Text('حجم الخط', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _subtitleFontSize,
                          min: 10,
                          max: 32,
                          divisions: 11,
                          activeColor: const Color(0xFFFF5238),
                          onChanged: (value) {
                            setState(() => _subtitleFontSize = value);
                            _saveSubtitleSettings();
                            setModalState(() {});
                          },
                        ),
                      ),
                      Text('${_subtitleFontSize.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),

                  // لون الخط
                  Row(
                    children: [
                      const Text('لون الخط', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 8),
                      _buildColorOption(Colors.white, setModalState),
                      _buildColorOption(Colors.yellow, setModalState),
                      _buildColorOption(Colors.green, setModalState),
                      _buildColorOption(Colors.cyan, setModalState),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorOption(Color color, StateSetter setModalState) {
    final isSelected = _subtitleColor == color;
    return GestureDetector(
      onTap: () {
        setState(() => _subtitleColor = color);
        _saveSubtitleSettings();
        setModalState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5238) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  // ============ جلب ترجمة عربية ============
  Future<void> _fetchArabicSubtitle() async {
    if (_openSubtitlesApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مفتاح OpenSubtitles غير مضبوط. تأكد من إضافة GitHub Secret.')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جارٍ البحث عن ترجمة عربية...')),
      );

      final searchUrl = Uri.parse(
        'https://api.opensubtitles.com/api/v1/subtitles?query=${Uri.encodeComponent(widget.channelName)}&languages=ar',
      );

      final response = await http.get(
        searchUrl,
        headers: {
          'Api-Key': _openSubtitlesApiKey,
          'User-Agent': 'PlayerPro v1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('فشل البحث (HTTP ${response.statusCode})');
      }

      final data = json.decode(response.body);
      final subtitles = data['data'] as List? ?? [];

      if (subtitles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على ترجمة عربية لهذا الفيلم')),
          );
        }
        return;
      }

      final firstSub = subtitles.first;
      final fileId = firstSub['attributes']?['files']?[0]?['file_id'];

      if (fileId == null) throw Exception('لم يتم العثور على ملف الترجمة');

      final downloadUrl = Uri.parse('https://api.opensubtitles.com/api/v1/download');
      final downloadResponse = await http.post(
        downloadUrl,
        headers: {
          'Api-Key': _openSubtitlesApiKey,
          'User-Agent': 'PlayerPro v1.0',
          'Content-Type': 'application/json',
        },
        body: json.encode({'file_id': fileId}),
      );

      if (downloadResponse.statusCode != 200) {
        throw Exception('فشل الحصول على رابط التحميل');
      }

      final downloadData = json.decode(downloadResponse.body);
      final link = downloadData['link'];

      if (link == null) throw Exception('رابط التحميل غير متوفر');

      await player.setSubtitleTrack(
        SubtitleTrack.uri(
          link,
          title: 'العربية',
          language: 'ar',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحميل الترجمة العربية بنجاح')),
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch subtitle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل جلب الترجمة: ${e.toString()}')),
        );
      }
    }
  }

  // ============ اختيار ملف ترجمة من الهاتف ============
  Future<void> _pickSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt'],
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;

      await player.setSubtitleTrack(
        SubtitleTrack.uri(
          'file://$filePath',
          title: 'ملف من الهاتف',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحميل ملف الترجمة بنجاح')),
        );
      }
    } catch (e) {
      debugPrint('Failed to pick subtitle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الملف: ${e.toString()}')),
        );
      }
    }
  }

  // ============ نسبة العرض ============
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
