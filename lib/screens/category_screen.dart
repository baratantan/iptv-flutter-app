import 'package:flutter/material.dart';
import 'package:muxa_xtream/muxa_xtream.dart';
import 'movie_details_screen.dart';

class CategoryScreen extends StatefulWidget {
  final XtCategory category;
  final String type; // 'movie' أو 'series'
  final String server;
  final String username;
  final String password;

  const CategoryScreen({
    super.key,
    required this.category,
    required this.type,
    required this.server,
    required this.username,
    required this.password,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCategoryContent();
  }

  Future<void> _loadCategoryContent() async {
    try {
      final portal = XtreamPortal.parse(widget.server);
      final credentials = XtreamCredentials(username: widget.username, password: widget.password);
      final client = XtreamClient(portal, credentials);

      List<dynamic> result;
      if (widget.type == 'movie') {
        // جلب أفلام هذا التصنيف
        result = await client.getVodStreams(categoryId: widget.category.id);
      } else {
        // جلب مسلسلات هذا التصنيف
        result = await client.getSeries(categoryId: widget.category.id);
      }

      setState(() {
        _items = result;
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
        title: Text(widget.category.name ?? 'التصنيف'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238)))
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _items.isEmpty
                  ? const Center(child: Text('لا توجد عناصر في هذا التصنيف', style: TextStyle(color: Colors.grey)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final name = item.name ?? 'بدون اسم';
                        final poster = item.posterUrl ?? '';

                        return GestureDetector(
                          onTap: () {
                            if (widget.type == 'movie') {
                              final streamUrl = '${widget.server}/movie/${widget.username}/${widget.password}/${item.streamId}.mp4';
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MovieDetailsScreen(
                                    movieName: name,
                                    streamUrl: streamUrl,
                                    posterUrl: poster,
                                  ),
                                ),
                              );
                            } else {
                              // المسلسلات: سنعرض رسالة مؤقتة
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('قريباً: عرض حلقات المسلسل')),
                              );
                            }
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: poster.isNotEmpty
                                      ? Image.network(poster, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.movie, size: 50))
                                      : const Icon(Icons.movie, size: 50),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
