import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _token;
  String? _userJson;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  String? get userJson => _userJson;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _userJson = prefs.getString('user_json');
    _isLoggedIn = _token != null && _token!.isNotEmpty;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> login(String token, String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_json', userJson);
    _token = token;
    _userJson = userJson;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_json');
    _token = null;
    _userJson = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
