import 'package:flutter/material.dart';
import 'package:resync/resync.dart';
import 'package:test_app/service/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _cachedData = [];
  String _getResponse = '';
  String _postResponse = '';

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final cacheManager = Resync.instance.cacheManager;
    final keys = cacheManager.getAllKeys();
    List<Map<String, dynamic>> cacheList = [];

    for (final key in keys) {
      final data = cacheManager.get(key);
      if (data != null) {
        cacheList.add({'url': key, 'data': data});
      }
    }

    setState(() {
      _cachedData = cacheList;
    });
  }

  Future<void> _performGetRequest() async {
    try {
      final response = await _apiService.getPost(2);
      setState(() {
        _getResponse = response.toString();
      });
    } catch (e) {
      setState(() {
        _getResponse = 'Error: $e';
      });
    }
    _loadCachedData();
  }

  Future<void> _performPostRequest() async {
    try {
      final response = await _apiService.createPost({
        'title': 'foo',
        'body': 'bar',
        'userId': 1,
      });
      setState(() {
        _postResponse = response.toString();
      });
    } catch (e) {
      setState(() {
        _postResponse = 'Error: $e';
      });
    }
    _loadCachedData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemplo Offline First'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _getResponse = '';
                _postResponse = '';
                _cachedData = [];
                _loadCachedData();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _performGetRequest,
              child: const Text('Fazer o GET'),
            ),
            const SizedBox(height: 8),
            Text(
              'GET Response: $_getResponse',
              overflow: TextOverflow.clip,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _performPostRequest,
              child: const Text('Fazer o POST'),
            ),
            const SizedBox(height: 8),
            Text('POST Response: $_postResponse'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadCachedData,
              child: const Text('Buscar cache'),
            ),
            const SizedBox(height: 24),
            const Text('Dados em Cache:'),
            Expanded(
              child: ListView.builder(
                itemCount: _cachedData.length,
                itemBuilder: (context, index) {
                  final cacheItem = _cachedData[index];
                  return ListTile(
                    title: Text(cacheItem['url']),
                    subtitle: Text(cacheItem['data'].toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
