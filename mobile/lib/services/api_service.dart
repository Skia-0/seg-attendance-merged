import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiService {
 static const String baseUrl = 'https://vice-reoccupy-rebuilt.ngrok-free.dev/api';
  static Dio _createDio({bool requiresAuth = false}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    if (requiresAuth) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ));
    }

    return dio;
  }

  static Future<Response> post(String path, Map<String, dynamic> data,
      {bool requiresAuth = false}) async {
    final dio = _createDio(requiresAuth: requiresAuth);
    return await dio.post(path, data: data);
  }

  static Future<Response> get(String path,
      {bool requiresAuth = false}) async {
    final dio = _createDio(requiresAuth: requiresAuth);
    return await dio.get(path);
  }


  static Future<Response> patch(String path, Map<String, dynamic> data,
    {bool requiresAuth = false}) async {
  final dio = _createDio(requiresAuth: requiresAuth);
  return await dio.patch(path, data: data);
}
}