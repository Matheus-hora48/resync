import 'package:dio/dio.dart';
import 'package:resync/resync.dart';

class ApiService {
  final Dio _dio;

  ApiService()
    : _dio = Dio(BaseOptions(
      baseUrl: 'http://192.168.1.236:3048/posts')) {
    _dio.interceptors.addAll([
      LogInterceptor(requestBody: true, responseBody: true),
      ResyncDioInterceptor(
        cacheManager: Resync.instance.cacheManager,
        syncManager: Resync.instance.syncManager,
        connectivityService: Resync.instance.connectivityService,
      ),
    ]);
  }

  Future<Map<String, dynamic>> getPost(int id) async {
    final response = await _dio.get('');
    return response.data;
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    final response = await _dio.post('', data: data);
    return response.data;
  }
}
