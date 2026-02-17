// lib/providers/auth_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/api/api_service.dart';
import '../services/realtime/realtime_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  
  UserModel? _user;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  File? _tempProfileImage; // Temporary image before upload

  // Getters
  UserModel? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCustomer => _user?.role == 'customer' || _user?.role == null;
  bool get isVendor => _user?.role == 'vendor';
  bool get isRider => _user?.role == 'rider';
  bool get isAdmin => _user?.role == 'admin';
  File? get tempProfileImage => _tempProfileImage;
  ApiService get apiService => _apiService; // Expose for direct API calls

  // Initialize
  Future<void> initialize() async {
    try {
      print('🔄 Initializing AuthProvider...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token != null) {
        print('✅ Token found in storage: ${token.substring(0, 20)}...');
        _token = token;
        _apiService.setToken(token);
        
        try {
          final response = await _apiService.get('/api/auth/me');
          _user = UserModel.fromJson(response['user'] ?? response['data']);
          _isAuthenticated = true;
          print('✅ User authenticated: ${_user?.email}, Role: ${_user?.role}');

          final current = _user;
          final tokenValue = _token;
          if (current?.id != null && tokenValue != null && tokenValue.isNotEmpty) {
            RealtimeService().connect(
              token: tokenValue,
              userId: current!.id!,
              role: current.role ?? 'customer',
            );
          }
        } catch (e) {
          print('❌ Failed to verify token: $e');
          await logout();
        }
      } else {
        print('ℹ️ No token found in storage');
      }
      notifyListeners();
    } catch (e) {
      print('❌ Error initializing auth: $e');
      await logout();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔐 Attempting login for: $email');
      final response = await _apiService.login(email, password);

      final userJson = response['user'];
      final token = response['access_token'] ?? '';
      
      _user = UserModel.fromJson({
        ...userJson,
        'token': token,
      });
      
      _token = token;
      _isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      _apiService.setToken(token);
      
      print('✅ Login successful - User: ${_user?.email}, Role: ${_user?.role}');
      print('✅ Token saved: ${token.substring(0, 20)}...');

      final current = _user;
      final tokenValue = _token;
      if (current?.id != null && tokenValue != null && tokenValue.isNotEmpty) {
        RealtimeService().connect(
          token: tokenValue,
          userId: current!.id!,
          role: current.role ?? 'customer',
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseAuthError(e.toString(), 'login');
      _isLoading = false;
      notifyListeners();
      print('❌ Login error: $e');
      return false;
    }
  }

  Future<bool> register(String email, String password, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📝 Attempting registration for: $email with role: $role');
      final response = await _apiService.post('/api/auth/register', {
        'email': email,
        'password': password,
        'role': role,
      });

      _user = UserModel.fromJson(response['user'] ?? response['data']);
      _isAuthenticated = true;

      final token = _user!.token ?? response['access_token'];
      if (token != null) {
        _token = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        _apiService.setToken(token);
        print('✅ Registration successful - Token saved');
      }

      final current = _user;
      final tokenValue = _token;
      if (current?.id != null && tokenValue != null && tokenValue.isNotEmpty) {
        RealtimeService().connect(
          token: tokenValue,
          userId: current!.id!,
          role: current.role ?? role,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseAuthError(e.toString(), 'register');
      _isLoading = false;
      notifyListeners();
      print('❌ Registration error: $e');
      return false;
    }
  }

  // Error parsing helper
  String _parseAuthError(String error, String action) {
    // Remove technical prefixes
    error = error.replaceAll('Exception: Failed to perform POST request: ', '')
                .replaceAll('Exception: API Error: ', '')
                .replaceAll('Exception: ', '');
    
    // Parse common authentication errors
    if (error.contains('Invalid credentials') || error.contains('incorrect password')) {
      return 'Invalid email or password. Please try again.';
    }
    
    if (error.contains('User not found') || error.contains('not found')) {
      return 'No account found with this email. Please register first.';
    }
    
    if (error.contains('already exists') || error.contains('Email already registered')) {
      return 'An account with this email already exists. Try logging in instead.';
    }
    
    if (error.contains('Network') || error.contains('Connection') || error.contains('Failed host lookup')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    if (error.contains('timeout') || error.contains('Timeout')) {
      return 'Request timeout. The server is taking too long to respond.';
    }
    
    if (error.contains('500') || error.contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    }
    
    if (error.contains('400') || error.contains('Bad Request')) {
      return 'Invalid request. Please check your information and try again.';
    }
    
    if (error.contains('403') || error.contains('Forbidden')) {
      return 'Access denied. You don\'t have permission to perform this action.';
    }
    
    if (error.contains('404')) {
      return 'Service not found. Please contact support.';
    }
    
    // Default messages based on action
    if (action == 'login') {
      return 'Login failed. Please check your credentials and try again.';
    } else if (action == 'register') {
      return 'Registration failed. Please try again or contact support.';
    }
    
    // Fallback: Return cleaned error
    return error.isEmpty ? 'An error occurred. Please try again.' : error;
  }

  // Profile Picture Methods
  Future<void> pickProfileImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        _tempProfileImage = File(pickedFile.path);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error picking image: $e';
      print('❌ Error picking image: $e');
      notifyListeners();
    }
  }

  Future<void> takeProfilePhotoWithCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        _tempProfileImage = File(pickedFile.path);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error taking photo: $e';
      print('❌ Error taking photo: $e');
      notifyListeners();
    }
  }

  Future<bool> uploadProfileImage() async {
    if (_tempProfileImage == null) return false;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.uploadProfileImage(_tempProfileImage!);
      
      if (response['profile_image'] != null || response['user'] != null) {
        final userData = response['user'] ?? response;
        final updatedUser = UserModel.fromJson({
          ..._user?.toJson() ?? {},
          ...userData,
        });
        
        _user = updatedUser;
        _tempProfileImage = null;
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = 'Failed to upload profile image';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Upload failed: $e';
      _isLoading = false;
      notifyListeners();
      print('❌ Error uploading profile image: $e');
      return false;
    }
  }

  void clearTempProfileImage() {
    _tempProfileImage = null;
    notifyListeners();
  }

  // Update user profile information
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateUserProfile(data, token: _token);
      
      if (response['user'] != null) {
        final updatedUser = UserModel.fromJson({
          ..._user?.toJson() ?? {},
          ...response['user'],
        });
        
        _user = updatedUser;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = 'Failed to update profile';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('❌ Update profile error: $e');
      return false;
    }
  }

  // Update user with new data (e.g., after avatar selection)
  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    print('🔓 Logging out...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _apiService.clearToken();
    RealtimeService().disconnect();
    
    _user = null;
    _token = null;
    _isAuthenticated = false;
    _tempProfileImage = null;
    _error = null;
    notifyListeners();
    print('✅ Logout complete');
  }

  /// Change user password
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      print('🔐 Attempting to change password...');
      final response = await _apiService.post(
        '/api/auth/change-password',
        {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );

      if (response['success'] == true) {
        print('✅ Password changed successfully');
        return true;
      } else {
        _error = response['error']?.toString() ?? 'Failed to change password';
        notifyListeners();
        print('❌ Error: $_error');
        return false;
      }
    } catch (e) {
      _error = 'Error changing password: ${e.toString()}';
      notifyListeners();
      print('❌ Exception: $_error');
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
