import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    
    // تشغيل رابط البث
    player.open(Media(widget.streamUrl));
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
