import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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

  bool _isLoading = true;
  String? _errorMessage;
  String? _localStreamUrl;
  int? _torrentId;
  StreamSubscription? _torrentSubscription;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    _initializeStream();
  }

  Future<void> _initializeStream() async {
    try {
      if (widget.streamUrl.startsWith('magnet:')) {
        await _initTorrentStream(widget.streamUrl);
      } else {
        _localStreamUrl = widget.streamUrl;
        await _playMedia(_localStreamUrl!);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _initTorrentStream(String magnetUrl) async {
    final id = LibtorrentFlutter.instance.addMagnet(magnetUrl);
    _torrentId = id;

    final completer = Completer<void>();

    _torrentSubscription = LibtorrentFlutter.instance.torrentUpdates.listen((torrents) {
      final t = torrents[id];
      if (t == null) return;

      if (t.hasMetadata && !completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;

    final stream = LibtorrentFlutter.instance.startStream(
      id,
      maxCacheBytes: 500 * 1024 * 1024,
    );

    _localStreamUrl = stream.url;
    await _playMedia(_localStreamUrl!);
  }

  Future<void> _playMedia(String url) async {
    await player.open(Media(url));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _torrentSubscription?.cancel();
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238)))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : Center(
                  child: Video(
                    controller: controller,
                    controls: AdaptiveVideoControls,
                  ),
                ),
    );
  }
}
