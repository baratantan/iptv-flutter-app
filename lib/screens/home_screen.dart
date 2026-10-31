import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muxa_xtream/muxa_xtream.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _liveStreams = [];

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  Future<void> _loadStreams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('xtream_server') ?? '';
      final username = prefs.getString('xtream_username') ?? '';
      final password = prefs.getString('xtream_password') ?? '';

      if (server.isEmpty) {
        throw Exception('لم يتم العثور على بيانات الاتصال');
      }

      final client = XtreamClient(
        serverUrl: server,
        username: username,
        password: password,
      );

      // جلب القنوات المباشرة
      final streams = await client.getLiveStreams();

      setState(() {
        _liveStreams = streams ?? [];
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
      appBar: AppBar(
        title: const Text('القنوات المباشرة'),
        backgroundColor: const Color(0xFF111827),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5238)))
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _liveStreams.length,
                  itemBuilder: (context, index) {
                    final stream = _liveStreams[index];
                    return ListTile(
                      leading: stream.streamIcon != null && stream.streamIcon!.isNotEmpty
                          ? Image.network(stream.streamIcon!, width: 50, height: 50, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                          : const Icon(Icons.tv),
                      title: Text(stream.name ?? 'بدون اسم'),
                      subtitle: Text('ID: ${stream.streamId}'),
                    );
                  },
                ),
    );
  }
}
