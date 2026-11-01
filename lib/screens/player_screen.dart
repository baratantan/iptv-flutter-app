import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:floating/floating.dart';

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
  final Floating _floating = Floating();
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
    final available = await _floating.isPipAvailable;
    if (mounted) {
      setState(() {
        _isPipAvailable = available;
      });
    }
  }

  Future<void> _enterPipMode() async {
    if (_isPipAvailable) {
      await _floating.enable(ImmediatePiP());
    }
  }

  @override
  void dispose() {
    _floating.dispose();
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
