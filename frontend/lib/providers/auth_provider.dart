import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email: email, password: password);
      _user = UserModel.fromJson(response['user'] ?? response);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String fullName,
    required String phoneNumber,
    required String password,
    required String passwordConfirm,
    String? referralCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        password: password,
        passwordConfirm: passwordConfirm,
        referralCode: referralCode,
      );
      _user = UserModel.fromJson(response['user'] ?? response);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadProfile() async {
    try {
      final profile = await ApiService.getProfile();
      _user = UserModel.fromJson(profile['user'] ?? profile);
      notifyListeners();
    } catch (e) {
      print('Erreur lors du chargement du profil: $e');
    }
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
