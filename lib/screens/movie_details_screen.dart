import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'player_screen.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String movieName;
  final String streamUrl;
  final String? posterUrl;
  final String? streamId;
  final String? server;
  final String? username;
  final String? password;

  const MovieDetailsScreen({
    super.key,
    required this.movieName,
    required this.streamUrl,
    this.posterUrl,
    this.streamId,
    this.server,
    this.username,
    this.password,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isLoading = true;
  bool _isFavorite = false;
  
  String? _plot;
  String? _duration;
  String? _rating;
  String? _releaseDate;

  @override
  void initState() {
    super.initState();
    _loadMovieInfo();
    _checkFavorite();
  }

  String get cleanMovieName {
    String cleaned = widget.movieName;
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*\[?MULTI-SUB\]?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[?MULTI-SUB\]?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Z]{2,3}\s*-\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  Future<void> _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorite_movies');
    if (favoritesJson != null) {
      final List<dynamic> decoded = json.decode(favoritesJson);
      final favorites = decoded.cast<String>();
      setState(() {
        _isFavorite = favorites.contains(widget.movieName);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorite_movies');
    List<String> favorites = [];
    if (favoritesJson != null) {
      final List<dynamic> decoded = json.decode(favoritesJson);
      favorites = decoded.cast<String>();
    }
    
    if (favorites.contains(widget.movieName)) {
      favorites.remove(widget.movieName);
    } else {
      favorites.add(widget.movieName);
    }
    
    await prefs.setString('favorite_movies', json.encode(favorites));
    setState(() {
      _isFavorite = !_isFavorite;
    });
  }

  Future<void> _loadMovieInfo() async {
    try {
      if (widget.streamId == null || widget.server == null || 
          widget.username == null || widget.password == null) {
        setState(() => _isLoading = false);
        return;
      }

      final portal = XtreamPortal.parse(widget.server!);
      final credentials = XtreamCredentials(
        username: widget.username!, 
        password: widget.password!,
      );
      final client = XtreamClient(portal, credentials);

      final info = await client.getVodInfo(int.tryParse(widget.streamId!) ?? 0);
      
      if (info != null) {
        if (mounted) {
          setState(() {
            _plot = info.plot;
            // تحويل Duration إلى نص
            _duration = info.duration?.inMinutes != null 
                ? '${info.duration!.inMinutes} دقيقة' 
                : null;
            _rating = info.rating?.toString();
            _releaseDate = info.year?.toString();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Failed to load movie info: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  child: widget.posterUrl != null && widget.posterUrl!.isNotEmpty
                      ? Image.network(
                          widget.posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
                        )
                      : Container(color: Colors.grey[900]),
                ),
                Positioned.fill(
                  child: Container(
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
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                cleanMovieName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_releaseDate != null && _releaseDate!.isNotEmpty)
                    _buildBadge(_releaseDate!, Colors.blue),
                  if (_duration != null && _duration!.isNotEmpty)
                    _buildBadge(_duration!, Colors.orange),
                  if (_rating != null && _rating!.isNotEmpty && _rating != '0.0')
                    _buildBadge('⭐ $_rating', Colors.amber),
                  if (widget.movieName.toUpperCase().contains('MULTI-SUB'))
                    _buildBadge('MULTI-SUB', Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(
                              streamUrl: widget.streamUrl,
                              channelName: cleanMovieName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, size: 30),
                      label: const Text(
                        'تشغيل الفيلم',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5238),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isFavorite ? Colors.amber : Colors.grey[700]!,
                        width: 1.5,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.amber : Colors.grey,
                        size: 28,
                      ),
                      padding: const EdgeInsets.all(14),
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Color(0xFFFF5238)),
              ))
            else if (_plot != null && _plot!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('القصة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_plot!, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.6)),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
