import '../services/api_service.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class CoordinatorProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _fullName;
  String? _coordinatorId;
  String? _hubId;
  String? _token;
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get fullName => _fullName;
  String? get coordinatorId => _coordinatorId;
  String? get hubId => _hubId;
  String? get token => _token;
  bool get isLoading => _isLoading;

  Future<void> checkLoginStatus() async {
    final token = await StorageService.getToken();
    if (token != null) {
      _token = token;
      _fullName = await StorageService.getFullName();
      _coordinatorId = await StorageService.getUserId();
      _hubId = await StorageService.getHubId();
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();

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

      _token = data['access_token'];
      _fullName = data['full_name'];
      _coordinatorId = data['coordinator_id'];
      _hubId = data['hub_id'];
      _isLoggedIn = true;

      _isLoading = false;
      notifyListeners();
      return {'success': true, 'data': data};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'Login failed. Check your credentials.'};
    }
  }

  Future<void> logout() async {
    await StorageService.clearAll();
    _isLoggedIn = false;
    _fullName = null;
    _coordinatorId = null;
    _hubId = null;
    _token = null;
    notifyListeners();
  }
}