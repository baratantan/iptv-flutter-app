import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:local_pip/local_pip.dart';

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

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    player.open(Media(widget.streamUrl));
    _checkPipAvailability();
  }

  Future<void> _checkPipAvailability() async {
    try {
      final available = await _localPip.isPipAvailable();
      if (mounted) {
        setState(() {
          _isPipAvailable = available;
        });
      }
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

  @override
  void dispose() {
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
          if (_isPipAvailable)
            IconButton(
              icon: const Icon(Icons.picture_in_picture_alt),
              onPressed: _enterPipMode,
              tooltip: 'صورة داخل صورة',
            ),
        ],
      ),
      body: Center(
        child: Video(
          controller: controller,
          controls: AdaptiveVideoControls,
        ),
      ),
    );
  }
}
