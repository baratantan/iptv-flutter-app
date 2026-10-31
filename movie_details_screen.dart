import 'package:flutter/material.dart';
import 'player_screen.dart';

class MovieDetailsScreen extends StatelessWidget {
  final String movieName;
  final String streamUrl;
  final String? posterUrl;

  const MovieDetailsScreen({
    super.key,
    required this.movieName,
    required this.streamUrl,
    this.posterUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 400,
                  width: double.infinity,
                  child: posterUrl != null && posterUrl!.isNotEmpty
                      ? Image.network(posterUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900]))
                      : Container(color: Colors.grey[900]),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF0B0E14).withOpacity(0.9), const Color(0xFF0B0E14)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(movieName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => PlayerScreen(streamUrl: streamUrl, channelName: movieName)),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 30),
                label: const Text('تشغيل الفيلم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5238),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
