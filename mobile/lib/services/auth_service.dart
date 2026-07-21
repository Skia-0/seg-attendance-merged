import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String password,
    required String hubId,
  }) async {
    try {
      final response = await ApiService.post('/auth/coordinator/register', {
        'full_name': fullName,
        'phone': phone,
        'password': password,
        'hub_id': hubId,
      });
      return {'success': true, 'data': response.data};
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await ApiService.post('/auth/coordinator/login', {
        'phone': phone,
        'password': password,
      });

      final data = response.data;
      await StorageService.saveUserData(
        token: data['access_token'],
        userId: data['coordinator_id'],
        segId: '',
        fullName: data['full_name'],
        hubId: data['hub_id'],
      );

      return {'success': true, 'data': data};
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<void> logout() async {
    await StorageService.clearAll();
  }

  static Map<String, dynamic> _handleError(dynamic e) {
    String message = 'Something went wrong. Please try again.';
    if (e.runtimeType.toString().contains('DioException')) {
      final response = (e as dynamic).response;
      if (response != null && response.data != null) {
        message = response.data['error'] ?? message;
      }
    }
    return {'success': false, 'error': message};
  }
}
